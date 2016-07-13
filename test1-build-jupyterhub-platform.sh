#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

if [ "$DATADIR" = "" ]; then
    # Default to putting output in the code directory, which means
    # a separate clone of the repository for each build
    DATADIR="$ORGCODEDIR"
fi
source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

# Maybe the multiple build scripts in this directory could share the
# same .conf, but overall it is probably simpler to keep them
# separate.  Hopefully there will be time to revisit this decision
# when thinking more about best practices for bashsteps and $DATADIR.

DATADIRCONF="$DATADIR/datadir-jh.conf"

# avoids errors on first run, but maybe not good to change state
# outside of a step
touch  "$DATADIRCONF"

source "$DATADIRCONF"

imagesource="$DATADIR/vmimages/centos-7.1.1511-x86_64-base/output/minimal-image.raw.tar.gz"

(
    $starting_group "Build minimal Centos 7 image"
    [ -f "$imagesource" ]
    $skip_group_if_unnecessary ; set -e

    "$DATADIR/vmimages/centos-7.1.1511-x86_64-base/build.sh"

    (
	$starting_step "Setup user/sshkey for use by ind-steps/kvmsteps"
	[ -f "${imagesource%.tar.gz}.sshuser" ]
	$skip_step_if_already_done; set -e
	cp "${imagesource%/*}/tmp-sshkeypair" "${imagesource%.tar.gz}.sshkey"
	echo "root" >"${imagesource%.tar.gz}.sshuser"

    ) ; prev_cmd_failed
) ; prev_cmd_failed

VMDIR=jhvmdir

(
    $starting_group "Setup clean VM for Jupterhub/Docker"
    # not currently snapshotting this VM, but if the next snapshot exists
    # then this group can be skipped.
    [ -f "$DATADIR/$VMDIR/minimal-image-w-jupyterhub-docker.raw.tar.gz" ]
    $skip_group_if_unnecessary

    (
	$starting_step "Make $VMDIR"
	[ -d "$DATADIR/$VMDIR" ]
	$skip_step_if_already_done ; set -e
	mkdir "$DATADIR/$VMDIR"
	# increase default mem to give room for a wakame instance or two
	echo ': ${KVMMEM:=4096}' >>"$DATADIR/$VMDIR/datadir.conf"
	[ -f "$DATADIR/datadir-jh.conf" ] || reportfailed "datadir-jh.conf is required"
	cat "$DATADIR/datadir-jh.conf" >>"$DATADIR/$VMDIR/datadir.conf"
    ) ; prev_cmd_failed

    DATADIR="$DATADIR/$VMDIR" \
	   "$ORGCODEDIR/ind-steps/kvmsteps/kvm-setup.sh" \
	   "$DATADIR/vmimages/centos-7.1.1511-x86_64-base/output/minimal-image.raw.tar.gz"

    # TODO: this guard is awkward.
    [ -x "$DATADIR/$VMDIR/kvm-boot.sh" ] && \
	"$DATADIR/$VMDIR/kvm-boot.sh"

    (
	$starting_step "Create centos user account"
	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" [ -d /home/centos/.ssh ] 2>/dev/null
	}
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
adduser centos
echo 'centos ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
cp -a /root/.ssh /home/centos
chown -R centos:centos /home/centos/.ssh
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Allow sudo without tty"
	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
! grep '^Defaults[[:space:]]*requiretty' /etc/sudoers
EOF
	}
	$skip_step_if_already_done ; set -e
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
    sed -i "s/^\(^Defaults[[:space:]]*requiretty.*\)/# \1/" /etc/sudoers
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Change default login user to centos"
	[ $(< "$DATADIR/$VMDIR/sshuser") = "centos" ]
	$skip_step_if_already_done ; set -e
	echo "centos" >"$DATADIR/$VMDIR/sshuser"
    ) ; prev_cmd_failed

    for p in wget bzip2 rsync nc netstat strace lsof git tcpdump; do
	(
	    $starting_step "Install $p"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
		[ -f "$DATADIR/$VMDIR/minimal-image-w-jupyter.raw.tar.gz" ] || \
		    [[ "$("$DATADIR/$VMDIR/ssh-to-kvm.sh" sudo which $p 2>/dev/null)" = *$p* ]]
		# note: "which lsof" fails unless sudo is used
	    }
	    $skip_step_if_already_done ; set -e
	    package=$p
	    [ "$p" = "netstat" ] && package=net-tools # because package!=executable name
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo yum install -y $package
EOF
	) ; prev_cmd_failed
    done

) ; prev_cmd_failed

(
    $starting_group "Setup Jupterhub/Docker VM image"
    [ -f "$DATADIR/$VMDIR/minimal-image-w-jupyterhub-docker.raw.tar.gz" ]
    $skip_group_if_unnecessary

    (
	$starting_group "Docker stuff"
	(
	    $starting_step "Install Docker"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
		"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<<"which docker" 2>/dev/null 1>&2
	    }
	    $skip_step_if_already_done; set -e
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "curl -fsSL https://get.docker.com/ | sudo sh"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "sudo usermod -aG docker centos"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "sudo systemctl enable docker"
	    touch "$DATADIR/extrareboot" # necessary to make the usermod take effect in Jupyter environment
	) ; prev_cmd_failed

	if [ "$extrareboot" != "" ] || \
	       [ -f "$DATADIR/extrareboot" ] ; then  # this flag can also be set before calling ./build-nii.sh
	    rm -f "$DATADIR/extrareboot"
	    [ -x "$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" ] && \
		"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh"
	fi

	if [ -x "$DATADIR/$VMDIR/kvm-boot.sh" ]; then
	    "$DATADIR/$VMDIR/kvm-boot.sh"
	fi

	(
	    $starting_group "Try to load cached Jupyter docker image"
	    ! [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
	    $skip_group_if_unnecessary

	    (
		$starting_step "Load cached jupyter/minimal-notebook image"
		"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
		$skip_step_if_already_done
		# Note: in next line stdin is used for data, not a script to bash
		cat "$DATADIR/jupyter-in-docker-cached.tar.gz" | gunzip - | \
		    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "docker load"
	    ) ; prev_cmd_failed
	) ; prev_cmd_failed

	(
	    $starting_step "Do docker pull jupyter/minimal-notebook"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
docker pull jupyter/minimal-notebook
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Save cached Jupyter docker image"
	    [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF | gzip - >"$DATADIR/jupyter-in-docker-cached.tar.gz"
set -x
docker save jupyter/minimal-notebook
EOF
	) ; prev_cmd_failed
    ) ; prev_cmd_failed

    (
	$starting_group "Jupterhub stuff"
	(
	    $starting_step "Install epel-release"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
    [ -f /etc/yum.repos.d/epel.repo ]
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo yum install -y epel-release
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install python3"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
		[[ "$("$DATADIR/$VMDIR/ssh-to-kvm.sh" sudo which python3  2>/dev/null)" = *python3* ]]
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo yum install -y python34
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install a bunch of *-devel packages"
	    packagelist=(
		zlib-devel   bzip2-devel   openssl-devel   ncurses-devel   sqlite-devel readline-devel   tk-devel   gdbm-devel   db4-devel   libpcap-devel   xz-devel  npm
	    )
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
    for p in ${packagelist[@]}; do
        [ "\$p" = db4-devel ] && continue # not sure why rpm-q does not see this one
        rpm -q \$p >/dev/null || exit 1
    done
    exit 0
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo yum install -y ${packagelist[@]}
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install configurable-http-proxy"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
    [ -f /bin/configurable-http-proxy ]
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo npm install -g configurable-http-proxy
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install pip"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
		[[ "$("$DATADIR/$VMDIR/ssh-to-kvm.sh" sudo which pip  2>/dev/null)" = *pip* ]]
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -e
wget https://bootstrap.pypa.io/get-pip.py
chmod +x ./get-pip.py
sudo python3.4 get-pip.py
sudo yum -y install python-devel  python34-devel
sudo pip3 install jupyterhub ipython[notebook]
EOF
	) ; prev_cmd_failed

	# at this point, "sudo jupyterhub --no-ssl" should work

	(
	    $starting_step "Do git clone https://github.com/jupyterhub/dockerspawner"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
    [ -d dockerspawner ]
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
git clone https://github.com/jupyterhub/dockerspawner
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install dockerspawner"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
    [ -f /usr/lib/python3.4/site-packages/dockerspawner-0.5.0.dev-py3.4.egg-info ]
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -e ; set -x
cd dockerspawner/
sudo pip install -r requirements.txt
sudo python3 setup.py install
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Do docker pull jupyterhub/singleuser"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
docker images | grep jupyterhub/singleuser >/dev/null
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
docker pull jupyterhub/singleuser
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Generate and modify jupyterhub_config.py"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
    [ -f jupyterhub_config.py ] && grep -F '10.0.2.15' jupyterhub_config.py >/dev/null
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<'EOF'
set -e ; set -x
jupyterhub --generate-config

after_this_line_insert_this_line()
{
  text="${text/"$1"/$1$'\n'$2}"
}

text="$(cat jupyterhub_config.py)"

after_this_line_insert_this_line \
   "# c.JupyterHub.hub_ip = '127.0.0.1'" \
   "c.JupyterHub.hub_ip = '10.0.2.15'"

after_this_line_insert_this_line \
   "# c.JupyterHub.spawner_class = 'jupyterhub.spawner.LocalProcessSpawner'" \
   "c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'"

echo "$text" >jupyterhub_config.py

EOF
	) ; prev_cmd_failed
    ) ; prev_cmd_failed

    # at this point, "sudo jupyterhub --no-ssl" will deploy docker
    # containers on the same host

    (
	$starting_step "Remove /etc/docker/key.json to give swarm nodes unique keys"
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
[ -f /etc/docker/key.json ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo rm /etc/docker/key.json
EOF
    ) ; prev_cmd_failed

    [ -x "$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" ] && \
	"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh"

    (
	$starting_step "Make snapshot of image with jupyterhub/docker installed"
	[ -f "$DATADIR/$VMDIR/minimal-image-w-jupyterhub-docker.raw.tar.gz" ]
	$skip_step_if_already_done ; set -e
	cd "$DATADIR/$VMDIR/"
	tar czSvf  minimal-image-w-jupyterhub-docker.raw.tar.gz  minimal-image.raw
    ) ; prev_cmd_failed

) ; prev_cmd_failed

(
    $starting_group "Boot three VMs"

    boot-one-vm()
    {
	avmdir="$1"
	(
	    $starting_step "Make $avmdir"
	    [ -d "$DATADIR/$avmdir" ]
	    $skip_step_if_already_done ; set -e
	    mkdir "$DATADIR/$avmdir"
	    # increase default mem to give room for a wakame instance or two
	    echo ': ${KVMMEM:=4096}' >>"$DATADIR/$avmdir/datadir.conf"
	    [ -f "$DATADIR/$3" ] || reportfailed "$3 is required"
	    # copy specific port forwarding stuff to avmdir, so vmdir*/kvm-* scripts
	    # will have all config info
	    cat "$DATADIR/$3" >>"$DATADIR/$avmdir/datadir.conf"
	    # copy ssh info from main VM to note VMs:
	    cp "$DATADIR/$VMDIR/sshuser" "$DATADIR/$avmdir/sshuser"
	    cp "$DATADIR/$VMDIR/sshkey" "$DATADIR/$avmdir/sshkey"
	) ; prev_cmd_failed

	if ! [ -x "$DATADIR/$avmdir/kvm-boot.sh" ]; then
	    DATADIR="$DATADIR/$avmdir" \
		   "$ORGCODEDIR/ind-steps/kvmsteps/kvm-setup.sh" \
		   "$DATADIR/$VMDIR/minimal-image-w-jupyterhub-docker.raw.tar.gz"
	fi
	# Note: the (two) steps above will be skipped for the main KVM

	(
	    $starting_step "Expand fresh image from snapshot for $2"
	    [ -f "$DATADIR/$avmdir/minimal-image.raw" ]
	    $skip_step_if_already_done ; set -e
	    cd "$DATADIR/$avmdir/"
	    tar xzSvf ../$VMDIR/minimal-image-w-jupyterhub-docker.raw.tar.gz
	) ; prev_cmd_failed

	# TODO: this guard is awkward.
	[ -x "$DATADIR/$avmdir/kvm-boot.sh" ] && \
	    "$DATADIR/$avmdir/kvm-boot.sh"

	
	(
	    $starting_step "Setup private network for VM $avmdir"
	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<EOF 2>/dev/null
[ -f /etc/sysconfig/network-scripts/ifcfg-ens3 ]
EOF
	    $skip_step_if_already_done
	    addr=$(
		case "$2" in
		    *main*) echo 99 ;;
		    *1*) echo 1 ;;
		    *2*) echo 2 ;;
		    *) reportfailed "BUG"
		esac
		)
	    
	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<EOF
sudo tee /etc/sysconfig/network-scripts/ifcfg-ens3 <<EOF2
DEVICE=ens3
BOOTPROTO=none
ONBOOT=yes
PREFIX=24
IPADDR=192.168.11.$addr
EOF2

sudo service network restart

EOF
	) ; prev_cmd_failed
    }

    boot-one-vm "$VMDIR" "main KVM" datadir-jh.conf
    boot-one-vm "$VMDIR-node1" "node 1 KVM" datadir-jh-node1.conf
    boot-one-vm "$VMDIR-node2" "node 2 KVM" datadir-jh-node2.conf

) ; prev_cmd_failed

(
    $starting_step "Make sure mac addresses were configured"
    # Make sure all three mac addresses are unique
    [ $(grep -ho 'export.*mcastMAC.*' "$DATADIR"/jhvmdir*/*conf | sort -u | wc -l) -eq 3 ]
    $skip_step_if_already_done
    # always fail if this has not been done
    reportfailed "Add mcastMAC= to: datadir-jh.conf datadir-jh-node2.conf datadir-jh-node1.conf"
) ; prev_cmd_failed

(
    $starting_group "Docker Swarm and Docker-Machine stuff"

    (
	$starting_step "Install docker-machine to main KVM"
	## https://docs.docker.com/machine/install-machine/
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
[ -x /usr/local/bin/docker-machine ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<'EOF'
set -x
sudo curl -L https://github.com/docker/machine/releases/download/v0.7.0/docker-machine-`uname -s`-`uname -m` -o /usr/local/bin/docker-machine && \
  sudo chmod +x /usr/local/bin/docker-machine
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Copy private ssh key to main KVM"
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
[ -f .ssh/id_rsa ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -x
cat >.ssh/id_rsa <<EOF2
$(< "$DATADIR/$VMDIR/sshkey")
EOF2
chmod 600 .ssh/id_rsa
EOF
    ) ; prev_cmd_failed

    dm-create-one-vm()
    {
	avmdir="$1"
	(
	    $starting_step "Do 'docker-machine create' command for $2"
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
## TODO: is this a good way to check?
/usr/local/bin/docker-machine ls | grep -F 192.168.11.$3 1>/dev/null
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -x
/usr/local/bin/docker-machine create --driver generic   --generic-ip-address=192.168.11.$3 --generic-ssh-user=centos $4
EOF
	) ; prev_cmd_failed
    }

    dm-create-one-vm "$VMDIR" "main KVM" 99 main
    dm-create-one-vm "$VMDIR-node1" "node 1 KVM" 1 node1
    dm-create-one-vm "$VMDIR-node2" "node 2 KVM" 2 node2

    (
	$starting_step "Create a Swarm discovery token"
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
[ -f swarm-token.txt ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<'EOF'
set -x
eval $(docker-machine env manager)
docker run --rm swarm create > swarm-token.txt
echo "The new swarm token: '$(< swarm-token.txt)'"
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Run a Swarm container that functions as the primary manager"
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<'EOF' 2>/dev/null
set -x
[[ "$(docker ps)" == *swarm\ manage* ]]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<'EOF'
set -x
eval $(docker-machine env main)
thetoken="$(< swarm-token.txt)"
## TODO: double check the /etc/docker part
    docker run -d -p 3376:3376 -t -v /etc/docker:/certs:ro swarm manage -H 0.0.0.0:3376 --tlsverify --tlscacert=/certs/ca.pem --tlscert=/certs/server.pem --tlskey=/certs/server-key.pem token://$thetoken

EOF
    ) ; prev_cmd_failed

    start-node-agent-one-vm()
    {
	avmdir="$1"
	(
	    $starting_step "Start node agent for $2"
	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<'EOF' 2>/dev/null
[[ "$(docker ps)" == *swarm\ join* ]]
EOF
	    $skip_step_if_already_done
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -x
eval \$(docker-machine env $4)
thetoken="\$(< swarm-token.txt)"
docker run -d swarm join --addr=\$(docker-machine ip $4):2376 token://\$thetoken

EOF
	) ; prev_cmd_failed
    }

    start-node-agent-one-vm "$VMDIR-node1" "node 1 KVM" 1 node1
    start-node-agent-one-vm "$VMDIR-node2" "node 2 KVM" 2 node2

) ; prev_cmd_failed
