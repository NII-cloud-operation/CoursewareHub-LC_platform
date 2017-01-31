#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

DATADIR="$1"

[ -L "$1/build-jh-environment.sh" ] || reportfailed "First parameter must be the datadir"

DATADIR="$(readlink -f "$DATADIR")"

source "$DATADIR/datadir.conf" || reportfailed

source "$ORGCODEDIR/../../simple-defaults-for-bashsteps.source" || reportfailed


# These are expected to exist before running the first time:
conffiles=(
    datadir-jh.conf
    datadir-jh-hub.conf
    $(
	for i in $node_list; do
	    echo datadir-jh-$i.conf
	done
    )
)

#for i in "${conffiles[@]}"; do
#    [ -f "$DATADIR/$i" ] || reportfailed "$i is required"
#done

## This script assumes link to ubuntu image is already at
## "$DATADIR/ubuntu-image-links/ubuntu-image.tar.gz"

VMDIR=jhvmdir

(
    $starting_group "Setup clean VM for hub and nodes"
    # not currently snapshotting this VM, but if the next snapshot exists
    # then this group can be skipped.
    [ -f "$DATADIR/$VMDIR/ubuntu-before-nbgrader.tar.gz" ]
    $skip_group_if_unnecessary

    "$DATADIR/$VMDIR/kvm-expand-fresh-image.sh" ; prev_cmd_failed

    "$DATADIR/$VMDIR/kvm-boot.sh" ; prev_cmd_failed

    (
	$starting_step "Allow sudo for ubuntu user account, remove mtod"
	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
	    SSHUSER=root "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
grep 'ubuntu.*ALL' /etc/sudoers >/dev/null
EOF
	$skip_step_if_already_done ; set -e

	SSHUSER=root "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
rm /etc/update-motd.d/*
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Added step to give VMs 8.8.8.8 for dns"
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null >/dev/null
grep -F "8.8.8.8" /etc/dhcp/dhclient.conf
EOF
	$skip_step_if_already_done

	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
# the next line is necessary or docker pulls do not work reliably
# related: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=625689
echo "prepend domain-name-servers 8.8.8.8;" | sudo tee -a /etc/dhcp/dhclient.conf
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Install git"
	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
which git
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo apt-get update
sudo apt-get -y install git
EOF
    ) ; prev_cmd_failed

    (
	$starting_group "Install ansible from source"
	# Installing from source because of note here:
	# https://github.com/compmodels/jupyterhub-deploy#deploying
	# also because install with "apt-get -y install ansible" raised this
	# problem: http://tracker.ceph.com/issues/12380

	#  Source install instructions:
	#  https://michaelheap.com/installing-ansible-from-source-on-ubuntu/
	#  http://docs.ansible.com/ansible/intro_installation.html

	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
which ansible
EOF
	$skip_group_if_unnecessary

	(
	    $starting_step "Install ansible build dependencies"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
		"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
false # always do this, let group block it
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
sudo apt-get update
sudo apt-get -y install python2.7 python-yaml python-paramiko python-jinja2 python-httplib2 make python-pip
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Clone ansible repository"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
		"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d ansible ]
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -e

### git clone https://github.com/ansible/ansible.git --recursive

git clone https://github.com/ansible/ansible.git
cd ansible

# reset to older version so that this error does not occur:
#
# TASK [nfs_server : bind home volume] *******************************************
# fatal: [hub]: FAILED! => {"changed": false, "failed": true, "msg": "Error mounting //home: /bin/mount: invalid option -- 'T'

git reset --hard a2d0bbed8c3f9de5d9c993e9b6f27f8af3eea438
git submodule update --init --recursive

EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Make/install ansible"
	    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
		"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
[ -x /usr/local/bin/ansible ]
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -e
cd ansible
sudo make install
EOF
	) ; prev_cmd_failed

    ) ; prev_cmd_failed

    (
	$starting_step "Clone https://github.com/(compmodels)/jupyterhub-deploy.git"
	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d jupyterhub-deploy ]
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
# clone from our exploration/debugging copy
git clone https://github.com/triggers/jupyterhub-deploy.git
#git clone https://github.com/compmodels/jupyterhub-deploy.git
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Adjust ansible config files for node_list"
	[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null
[ -f nodelist ] && [ "\$(cat nodelist)" = "$node_list" ]
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
node_list="$node_list"

[ -f jupyterhub-deploy/inventory.bak ] || cp jupyterhub-deploy/inventory jupyterhub-deploy/inventory.bak 

while IFS='' read -r ln ; do
   case "\$ln" in
     *jupyterhub_nodes*)
         echo "\$ln"
         for n in \$node_list; do
            echo \$n ansible_ssh_user=root ansible_ssh_host=192.168.11."\${n#node}" fqdn=\$n servicenet_ip=192.168.11."\${n#node}"
         done
         while IFS='' read -r ln ; do
             [[ "\$ln" == [* ]] && break
         done
         echo
         echo "\$ln"
         ;;
     *nfs_clients*)
         echo "\$ln"
         for n in \$node_list; do
            echo \$n
         done
         while IFS='' read -r ln ; do
             [[ "\$ln" == [* ]] && break
         done
         echo "\$ln"
         ;;
     *) echo "\$ln"
        ;;
   esac
done <jupyterhub-deploy/inventory.bak  >jupyterhub-deploy/inventory

[ -f jupyterhub-deploy/script/assemble_certs.bak ] || cp jupyterhub-deploy/script/assemble_certs jupyterhub-deploy/script/assemble_certs.bak

while IFS='' read -r ln ; do
   case "\$ln" in
     name_map\ =*)
         echo "\$ln"
         echo -n '    "hub": "hub"'
         for n in \$node_list; do
            echo ','
            printf '    "%s": "%s"' "\$n" "\$n"
         done
         while IFS='' read -r ln ; do
             [[ "\$ln" == }* ]] && break
         done
         echo
         echo "\$ln"
         ;;
     *) echo "\$ln"
        ;;
   esac
done <jupyterhub-deploy/script/assemble_certs.bak  >jupyterhub-deploy/script/assemble_certs
echo ------ jupyterhub-deploy/inventory ------------
diff jupyterhub-deploy/inventory.bak jupyterhub-deploy/inventory || :
echo ------ jupyterhub-deploy/script/assemble_certs ---------
diff  jupyterhub-deploy/script/assemble_certs.bak jupyterhub-deploy/script/assemble_certs || :
EOF
    ) ; prev_cmd_failed
) ; prev_cmd_failed

(
    $starting_group "Snapshot base KVM image"
    [ -f "$DATADIR/$VMDIR/ubuntu-before-nbgrader.tar.gz" ]
    $skip_group_if_unnecessary

    [ -x "$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" ] && \
	"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh"

    (
	$starting_step "Make snapshot of base image"
	[ -f "$DATADIR/$VMDIR/ubuntu-before-nbgrader.tar.gz" ]
	$skip_step_if_already_done ; set -e
	cd "$DATADIR/$VMDIR/"
	tar czSvf  ubuntu-before-nbgrader.tar.gz ubuntu-14-instance-build.img
	cp -a sshuser ubuntu-before-nbgrader.sshuser
	cp -a sshkey ubuntu-before-nbgrader.sshkey
    ) ; prev_cmd_failed

) ; prev_cmd_failed

(
    $starting_group "Boot three VMs"

    boot-one-vm()
    {
	avmdir="$1"

	"$DATADIR/$avmdir/kvm-expand-fresh-image.sh" ; prev_cmd_failed

	"$DATADIR/$avmdir/kvm-boot.sh" ; prev_cmd_failed

	# Note: the (two) steps above will be skipped for the main KVM

	(
	    $starting_step "Expand fresh image from snapshot for $2"
	    [ -f "$DATADIR/$avmdir/ubuntu-14-instance-build.img" ]
	    $skip_step_if_already_done ; set -e
	    cd "$DATADIR/$avmdir/"
	    tar xzSvf ../$VMDIR/ubuntu-before-nbgrader.tar.gz
	) ; prev_cmd_failed

	# TODO: this guard is awkward.
	[ -x "$DATADIR/$avmdir/kvm-boot.sh" ] && \
	    "$DATADIR/$avmdir/kvm-boot.sh"
	
	(
	    $starting_step "Setup private network for VM $avmdir"
	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<EOF 2>/dev/null >/dev/null
grep eth1 /etc/network/interfaces
EOF
	    $skip_step_if_already_done
	    addr=$(
		case "$2" in
		    *main*) echo 99 ;;
		    *hub*) echo 88 ;;
		    node*) echo "${2//[^0-9]}" ;; #TODO: refactor
		    *) reportfailed "BUG"
		esac
		)

	    # http://askubuntu.com/questions/441619/how-to-successfully-restart-a-network-without-reboot-over-ssh

	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<EOF
sudo tee -a /etc/network/interfaces <<EOF2

auto eth1
iface eth1 inet static
    address 192.168.11.$addr
    netmask 255.255.255.0
EOF2

# sudo ifdown eth1
sudo ifup eth1

EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Change hostname VM $avmdir"
	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<EOF 2>/dev/null >/dev/null
[[ "\$(hostname)" != *ubuntu* ]]
EOF
	    $skip_step_if_already_done
	    hn=$(
		case "$2" in
		    *main*) echo main ;;
		    *hub*) echo hub ;;
		    node*)
			tmpv="${2%KVM*}"
			echo "${tmpv// /}"   #TODO: refactor
			;;
		    *) reportfailed "BUG"
		esac
	      )
	    
	    "$DATADIR/$avmdir/ssh-to-kvm.sh" <<EOF
echo $hn | sudo tee /etc/hostname
echo 127.0.0.1 $hn | sudo tee -a /etc/hosts
sudo hostname $hn
EOF
	) ; prev_cmd_failed
    }

    boot-one-vm "$VMDIR" "main KVM" datadir-jh.conf
    boot-one-vm "$VMDIR-hub" "hub KVM" datadir-jh-hub.conf

    for n in $node_list; do
	boot-one-vm "$VMDIR-$n" "$n KVM" datadir-jh-$n.conf
    done

) ; prev_cmd_failed
exit
(
    $starting_step "Make sure mac addresses were configured"
    # Make sure all three mac addresses are unique
    nodesarray=( $node_list )
    vmcount=$(( ${#nodesarray[@]} + 2 )) # nodes + hub + ansible/main
    [ $(grep -ho 'export.*mcastMAC.*' "$DATADIR"/jhvmdir*/*conf | sort -u | wc -l) -eq "$vmcount" ]
    $skip_step_if_already_done
    # always fail if this has not been done
    reportfailed "Add mcastMAC= to: datadir-jh.conf datadir-jh-nodennn.conf"
) ; prev_cmd_failed
