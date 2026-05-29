#!/bin/bash
#sh create/delete mongodb redis ... or all

AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z00461041245SLKVHKSS7"
DOMAIN_NAME="trivikram.online"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $# -lt 2 ]; then
    echo -e " $R [ERROR ] : Please provide atleast two parameters $N "
    echo -e " $Y Syntax : sh $0 [create/delete] [instance1] [instance2] ..... $N "
    exit 1
fi

ACTION=$1

if [ "$ACTION" != "create " ] && [ "$ACTION" != "delete" ]; then
    echo -e " $Y Syntax : sh $0 [create/delete] [instance1] [instance2] ..... $N "
    exit 1
fi

shift

# Get the instance_id. below function will give some id if already that instance_name exists, or None if doesn't exists.
get_instance_id(){
    aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text
}

for instance in $@
do
    INSTANCE_ID=$(get_instance_id "$instance")

    #If create is given 
    if [ "$ACTION" == "create" ]; then
        #If no old EC2 instance already exists, create a new one
        if [ "$INSTANCE_ID" == "None"]; then
            echo " creating new instance for $instance "
            INSTANCE_ID=$(aws ec2 run-instances \
            --image-id $AMI_ID \
            --instance-type t3.micro \
            --security-groups "common" "$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
            --query 'Instances[0].InstanceId' \
            --output text )

            echo -e " $G created new instance for $instance $N "
            aws ec2 wait instance-running --instance-ids $INSTANCE_ID
            echo -e " $Y Instance ID : $INSTANCE_ID $N "

            else
            echo -e "$Y $instance already running: $INSTANCE_ID $N"
        fi

        if [ "$instance == "frontend" ]; then

            IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
            --query 'Reservations[*].Instances[*].PublicIpAddress' \
            --output text)

            R53_RECORD="$DOMAIN_NAME"

            else
                IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
                --query 'Reservations[*].Instances[*].PrivateIpAddress' \
                --output text)

                R53_RECORD="$instance.$DOMAIN_NAME"
        fi

        aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch '
            {
                "Comment": "Update A record to new IP",
                "Changes": [
                    {
                        "Action": "UPSERT",
                        "ResourceRecordSet": {
                            "Name": "'$R53_RECORD'",
                            "Type": "A",
                            "TTL": 1,
                            "ResourceRecords": [
                                {
                                    "Value": "'$IP'"
                                }
                            ]
                        }
                    }
                ]
            }
        '
        echo "updated R53 record for: $instance"

# If delete is given
        else
        #If already deleted 
        if [ "$INSTANCE_ID" == "None" ]; then
            echo "$instance already destroyed, nothing to do..."

# if not deleted, do it now
            else
                aws ec2 terminate-instances --instance-ids $INSTANCE_ID
                echo "Terminating Instance: $instance"
        fi
    fi
done