#!/bin/bash

source ./common.sh
check_root

dnf install mysql-server -y &>> $LOGS_FILE
VALIDATE $? "Installing MySQL Server"

systemctl enable mysqld &>> $LOGS_FILE
systemctl start mysqld  &>> $LOGS_FILE
VALIDATE $? "Enable and start MySQL server"

mysql_secure_installation --set-root-pass RoboShop@1
VALIDATE $? "Setting up root password"

print_total_time