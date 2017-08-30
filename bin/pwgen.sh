#!/bin/bash


source $(dirname $0)/const

hubdir=$1

password=$("$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i ${AUTH_PROXY_NAME} bash << EOF
php -r "require_once '/var/www/php/functions.php'; echo generate_password();"
EOF
)

echo $password
