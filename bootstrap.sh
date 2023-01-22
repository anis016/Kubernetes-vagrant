#!/usr/bin/env bash

# enable PasswordAuthentication
echo "[TASK 1] Enable ssh password authentication"
sudo sed -re "s/^(\#?)([[:space:]]?)PasswordAuthentication([[:space:]]+)no/PasswordAuthentication yes/" -i /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
service sshd restart

# set root password
echo "[TASK 2] Set root password"
echo -e "admin\nadmin" | passwd root >/dev/null 2>&1
