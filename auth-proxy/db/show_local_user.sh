#!/bin/bash

hubdir=$1

"$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q \
sudo docker exec -i root_jpydb_1 \
/usr/lib/postgresql/9.6/bin/psql -U postgres -d jupyterhub << EOS  

SELECT * FROM local_users; 

EOS

