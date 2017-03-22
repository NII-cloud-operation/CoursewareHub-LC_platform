#!/bin/bash

hubdir=$1
$user_name=$2

"$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q \
sudo docker exec -i root_jpydb_1 \
/usr/lib/postgresql/9.6/bin/psql -U postgres -d jupyterhub << EOS  

DELETE FROM local_users where user_name=$username;

EOS

