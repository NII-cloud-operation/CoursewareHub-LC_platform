#!/bin/bash

base_dir="$(dirname $(readlink -f "$0"))/.."
source $base_dir/ind-steps/build-jh-environment/bashsteps-defaults-jan2017-check-and-do.source || exit

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}


export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

rootdir="${ORGCODEDIR%/*}"

AUTH_PROXY_NAME=root_nginx_3

JUPYTER_USER_ID=1001

function init_jupyterhub()
{
    local hubdir="$1"  # Path to the build directory
    local teacher_mail="$2"
    local teacherid=""

    ## check parameters
    if [ "$#" -ne 2 ]; then 
        reportfailed "Too few arguments"
    fi
    [ -d "$hubdir" ] || reportfailed "Hub directory '$hubdir' does not exist."
    [ -z "$teacher_mail" ] && reportfailed "Administrator's email address does not specfied."

    #echo "hubdir: "$hubdir
    #echo "teacher_mail: "$teacher_mail

    # remove original proxy container
    (
        $starting_step "Remove original proxy container"
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker ps | grep root_nginx_1
        [ "$?" = 1 ]
        $skip_step_if_already_done

        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker rm -f root_nginx_1
    )

    # Generate local user id of teacher from teacher's mail address
    echo "** Generate local user id of teacher from mail address"
    teacherid=$("$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i ${AUTH_PROXY_NAME} bash << EOF
php -r "require_once '/var/www/php/functions.php'; echo get_username_from_mail_address('"$teacher_mail"');"
EOF
)
    echo "teacherid: "$teacherid 

    # Configure jupyterhub 
    (
        $starting_step "Reconfigure JupyterHub"
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i root_jupyterhub_1 bash << EOF | grep -q RemoteUserLocalAuthenticator
cat /srv/jupyterhub_config/jupyterhub_config.py
EOF
        $skip_step_if_already_done

        reconfigure_one_jupyterhub "$hubdir" "$teacherid"
    )
    (
        $starting_step "Patch JupyterHub"
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i root_jupyterhub_1 bash << EOF
[ -e "/opt/conda/lib/python3.5/site-packages/remote_user" ]
EOF
        $skip_step_if_already_done

        push_hub_patch "$hubdir" 1>/dev/null
    )
    (
        $starting_step "Create directory structure"
	"$hubdir/jhvmdir-hub/ssh-shortcut.sh" -q sudo [ -e "/jupyter/admin/$teacherid" ]
        $skip_step_if_already_done

        create_directory_structure "$hubdir" "$teacherid"
    )

    # generate ssh keys for local user operetion from teacher's Jupyter server
    (
        $starting_step "Generate ssh key for local user operetion"
        hub_ssh_key='ssh-hub'
	"$hubdir/jhvmdir-hub/ssh-shortcut.sh" -q sudo [ -e "/jupyter/admin/$teacherid/.ssh/$hub_ssh_key" ]
        $skip_step_if_already_done

        # genarate key
        ssh-keygen -t rsa -b 2048 -N "" -f /tmp/$hub_ssh_key

        # set ssh key for auth-proxy
        (cd /tmp; tar c $hub_ssh_key) | \
            "$hubdir/jhvmdir-hub/ssh-shortcut.sh" -q sudo tar xv -C /jupyter/admin/$teacherid/.ssh/
        rm /tmp/$hub_ssh_key
        # add ssh public key to authorized_keys
        cat "/tmp/${hub_ssh_key}.pub" | \
            "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q "sudo cat - >> /home/ubuntu/.ssh/authorized_keys"
        rm /tmp/${hub_ssh_key}.pub
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q "sudo chown -R '$JUPYTER_USER_ID:$JUPYTER_USER_ID' '/jupyter/admin/$teacherid/.ssh'"
    )

    # Restart JupyterHub
    echo "** Restarting JupyterHub container."
    "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker stop root_jupyterhub_1
    "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker start root_jupyterhub_1

    # Configuring auth-proxy container
    hubip="$(source "$hubdir/jhvmdir-hub/datadir.conf" ; echo "$VMIP")"
    dbip=$("$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker inspect --format='{{.NetworkSettings.IPAddress}}' root_jpydb_1)
    hubport=8000

    # configure hub-const.php
    (
        $starting_step "Configure hub-const.php"
        hub_const_path="/home/ubuntu/auth-proxy/php/hub-const.php"
	current_text="$("$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q cat $hub_const_path)"
	[[ "$current_text" == *${dbip}* ]] && [[ "$current_text" == *${hubip}:${hubport}* ]]
        $skip_step_if_already_done

        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q << EOF
sed -i "s,HUB_URL = .*,HUB_URL = \"http://$hubip:$hubport\";," $hub_const_path 
sed -i "s,DB_HOST = .*,DB_HOST = \"$dbip\";," $hub_const_path
EOF
    )

    # configure nginx.conf
    (
        $starting_step "Configure nginx.conf"
        nginx_conf_path=/etc/nginx/nginx.conf
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i ${AUTH_PROXY_NAME} bash << EOF | grep -q $hubip:$hubport
cat $nginx_conf_path
EOF
        $skip_step_if_already_done

        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i ${AUTH_PROXY_NAME} bash << EOF
sed -i "s,proxy_pass http:.*,proxy_pass http://$hubip:$hubport;," $nginx_conf_path
EOF
        # Restarting auth-proxy container
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker stop ${AUTH_PROXY_NAME}
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker start ${AUTH_PROXY_NAME}
        # Restarting auth-proxy daemons
        "$hubdir/jhvmdir-hub/ssh-shortcut.sh" -q << EOF
sudo docker exec -i ${AUTH_PROXY_NAME} bash << EOF2
(
  /etc/init.d/nginx start
  /etc/init.d/php5.6-fpm start
) >/tmp/dstart.log 2>&1
 The redirection is necessary otherwise init.d/nginx makes "docker exec" hang
EOF2
EOF
    )

    # configure .hub-config in the admin container
    (
        $starting_step "Configuring .hub-config."
        hub_config_name='.hub-config' 
        node_list="$(source "$hubdir/datadir.conf"; echo "$node_list")"
        array=""
        for node in $node_list; do
            ip=$(source "$hubdir/jhvmdir-${node}/datadir.conf"; echo "$VMIP")
            item="\"$node $ip"\"
            array+=$item" "
        done
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo bash << EOF | grep -q "$array"
set -e
[ -e /jupyter/admin/$teacherid/$hub_config_name ]
cat /jupyter/admin/$teacherid/$hub_config_name
EOF
        $skip_step_if_already_done

        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo bash << EOF
echo "HUB_IP=$hubip" > /jupyter/admin/$teacherid/$hub_config_name
echo "AUTH_PROXY_IP=$hubip" >> /jupyter/admin/$teacherid/$hub_config_name
echo "AUTH_PROXY_NAME=${AUTH_PROXY_NAME}" >> /jupyter/admin/$teacherid/$hub_config_name
echo 'NODES=(' >> /jupyter/admin/$teacherid/$hub_config_name
echo '$array' >> /jupyter/admin/$teacherid/$hub_config_name
echo ')' >> /jupyter/admin/$teacherid/$hub_config_name
chown "$JUPYTER_USER_ID:$JUPYTER_USER_ID" "/jupyter/admin/$teacherid/$hub_config_name"
EOF
    )

    "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo bash << EOF
chmod 755 /jupyter/admin/{textbook,admin_tools,tools,info}
EOF

    # Add database schema of local user
    (
        $starting_step "Add database schema of local user"
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i root_jpydb_1 \
        /usr/lib/postgresql/9.6/bin/psql -U postgres -d jupyterhub << EOF | grep -q local_users
select relname as table_name from pg_stat_user_tables;
EOF
        $skip_step_if_already_done

        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q \
        sudo docker exec -i root_jpydb_1 /usr/lib/postgresql/9.6/bin/psql -U postgres -d jupyterhub << EOF
CREATE SEQUENCE local_users_id_seq START 1;
CREATE TABLE local_users (
    id  integer CONSTRAINT firstkey PRIMARY KEY,
    user_name  varchar(64) UNIQUE NOT NULL,
    password  varchar(128) NOT NULL,
    mail  varchar(64) NOT NULL
);
EOF
    )

    # Register Course administrator
    (
        $starting_step "Register Course administrator."
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i root_jpydb_1 \
        /usr/lib/postgresql/9.6/bin/psql -U postgres -d jupyterhub << EOF | grep -q $teacherid
select user_name from local_users;
EOF
        $skip_step_if_already_done

        # generate password    
        password=$($rootdir/bin/pwgen.sh)

        # register teacher's userid and password
        "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i ${AUTH_PROXY_NAME} bash << EOF
php -r "require_once '/var/www/php/db.php'; add_local_user('$teacher_mail', '$password');"
EOF

        # notify password
        echo "----------"
        echo "admin password: "$password
        echo "----------"
    )

    echo "Done."
}

function reconfigure_one_jupyterhub()
{
    local hubdir="$1"
    local teacherid="$2"
    withslash=""

    # check parameters
    if [ "$#" -ne 2 ]; then 
        reportfailed "Too few arguments"
    fi
    "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i root_jupyterhub_1 bash << EOF
    cat >/srv/jupyterhub_users/userlist << EOF3
$teacherid admin
EOF3

    cat >>/srv/jupyterhub_config/jupyterhub_config.py << EOF2
# change to unix authentication:
c.JupyterHub.authenticator_class = 'remote_user.remote_user_auth.RemoteUserLocalAuthenticator'

c.JupyterHub.base_url='$withslash/'

EOF2

EOF
}

function push_hub_patch()
{
    local hubdir="$1"
    hppath="$rootdir/hub-patch-dir-tree"

    filelist="$(cd "$hppath" && ls)"

    (
	echo 'cd / || exit 0 ; tar xzv'
	cd "$rootdir/hub-patch-dir-tree" || exit
	# the tar on the prev line will start reading from stdin, which is provided by this tar:
	tar cz $filelist
    ) | "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo docker exec -i root_jupyterhub_1 bash
}


function create_directory_structure()
{
    local hubdir="$1"
    local teacherid="$2"

    "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo bash <<EOF
       mkdir -p /jupyter/admin/{textbook,admin_tools,tools,info}
       chmod a+rw /jupyter/admin/{textbook,admin_tools,tools,info}

       mkdir -p /jupyter/users
       chmod a+wr /jupyter/users

       if getent passwd $teacherid > /dev/null ; then
	   echo "User ($teacherid) exists on hub KVM"
       else
	   echo "Creating user ($teacherid)"
	   # the next line does not create the home directory
	   useradd -s /bin/bash "$teacherid"
       fi

       mkdir -p "/jupyter/admin/$teacherid"
       mkdir -p "/jupyter/admin/$teacherid/.ssh"

       ipycfg="/jupyter/admin/$teacherid/.ipython/profile_default/ipython_config.py"
       mkdir -p "\${ipycfg%/*}"
       echo "c.InteractiveShellApp.matplotlib = 'inline'" >>"\$ipycfg"

       # Note: probably because of NFS, sometimes programs think this
       # this next symbolic link is a directory when normally it would
       # be behave as the link itself.
       [ -L "/jupyter/admin/$teacherid/admin_tools" ] || \
            ln -s /jupyter/admin/admin_tools "/jupyter/admin/$teacherid/admin_tools"
       chown -R "$JUPYTER_USER_ID:$JUPYTER_USER_ID" "/jupyter/admin/$teacherid"
       chmod -R a+rw "/jupyter/admin/$teacherid"
EOF
    # update with latest version
    tar c adapt-notebooks-for-user.sh background-command-processor.sh | \
	"$hubdir/jhvmdir-hub/ssh-shortcut.sh" -q sudo tar xv -C /srv

    # TODO: redo this
    "$hubdir"/jhvmdir-hub/ssh-shortcut.sh -q sudo bash <<EOF
killall background-command-processor.sh
cd /srv
bash -c 'setsid ./background-command-processor.sh 1>>bcp.log 2>&1 </dev/null &'
EOF
}

teacher_mail=$TEACHER_MAIL
init_jupyterhub "$1" $teacher_mail
