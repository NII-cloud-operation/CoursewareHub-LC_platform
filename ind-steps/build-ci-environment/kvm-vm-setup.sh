#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# These are expected to exist before running the first time:
#conffiles=(
#    datadir-jh.conf
#    datadir-jh-hub.conf
#    $(
#	for i in $node_list; do
#	    echo datadir-jh-$i.conf
#	done
#    )
#)

#for i in "${conffiles[@]}"; do
#    [ -f "$DATADIR/$i" ] || reportfailed "$i is required"
#done

## This script assumes link to ubuntu image is already at
## "$DATADIR/ubuntu-image-links/ubuntu-image.tar.gz"

VMDIR=civmdir

(
    $starting_group "Setup clean VM for notebook"
    # not currently snapshotting this VM, but if the next snapshot exists
    # then this group can be skipped.
    [ -f "$DATADIR/$VMDIR/ubuntu-before-nbgrader.tar.gz" ]
    $skip_group_if_unnecessary

    "$DATADIR/$VMDIR/kvm-expand-fresh-image.sh" wrapped ; $iferr_exit

    "$DATADIR/$VMDIR/kvm-boot.sh" wrapped ; $iferr_exit

    (
	$starting_step "Allow sudo for ubuntu user account, remove mtod"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    SSHUSER=root "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
grep 'ubuntu.*ALL' /etc/sudoers >/dev/null
EOF
	$skip_step_if_already_done ; set -e

	SSHUSER=root "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
echo 'ubuntu ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
rm /etc/update-motd.d/*
EOF
    ) ; $iferr_exit

    (
	$starting_step "Added step to give VMs 8.8.8.8 for dns"
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
grep -F "8.8.8.8" /etc/dhcp/dhclient.conf
EOF
	$skip_step_if_already_done

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
# the next line is necessary or docker pulls do not work reliably
# related: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=625689
echo "prepend domain-name-servers 8.8.8.8;" | sudo tee -a /etc/dhcp/dhclient.conf
EOF
    ) ; $iferr_exit

    (
	$starting_step "Install git"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which git
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
sudo apt-get update
sudo apt-get -y install git
EOF
    ) ; $iferr_exit

    (
	$starting_group "Install ansible from source"
	# Installing from source because of note here:
	# https://github.com/compmodels/jupyterhub-deploy#deploying
	# also because install with "apt-get -y install ansible" raised this
	# problem: http://tracker.ceph.com/issues/12380

	#  Source install instructions:
	#  https://michaelheap.com/installing-ansible-from-source-on-ubuntu/
	#  http://docs.ansible.com/ansible/intro_installation.html

	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which ansible
EOF
	$skip_group_if_unnecessary

	(
	    $starting_step "Install ansible build dependencies"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
false # always do this, let group block it
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
sudo apt-get update
sudo apt-get -y install python2.7 python-yaml python-paramiko python-jinja2 python-httplib2 make python-pip
EOF
	) ; $iferr_exit

	(
	    $starting_step "Clone ansible repository"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d ansible ]
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
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
	) ; $iferr_exit

	(
	    $starting_step "Make/install ansible"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -x /usr/local/bin/ansible ]
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd ansible
sudo make install
EOF
	) ; $iferr_exit

    ) ; $iferr_exit

) ; $iferr_exit

(
    $starting_group "Snapshot base KVM image"
    [ -f "$DATADIR/$VMDIR/ubuntu-before-nbgrader.tar.gz" ]
    $skip_group_if_unnecessary

    "$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" wrapped ; $iferr_exit

    (
	$starting_step "Make snapshot of base image"
	[ -f "$DATADIR/$VMDIR/ubuntu-before-nbgrader.tar.gz" ]
	$skip_step_if_already_done ; set -e
	cd "$DATADIR/$VMDIR/"
	tar czSvf  ubuntu-before-nbgrader.tar.gz ubuntu-14-instance-build.img
	cp -a sshuser ubuntu-before-nbgrader.sshuser
	cp -a sshkey ubuntu-before-nbgrader.sshkey
	# TODO: should $imagesource be updated in datadir.conf?
    ) ; $iferr_exit

) ; $iferr_exit

(
    $starting_group "Boot CI VMs"

    boot-one-vm()
    {
	avmdir="$1"

	"$DATADIR/$avmdir/kvm-expand-fresh-image.sh" wrapped ; $iferr_exit

	"$DATADIR/$avmdir/kvm-boot.sh" wrapped ; $iferr_exit

	# Note: the (two) steps above will be skipped for the main KVM

	(
	    $starting_step "Setup private network for VM $avmdir"
	    "$DATADIR/$avmdir/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
grep eth1 /etc/network/interfaces
EOF
	    $skip_step_if_already_done
	    addr="$(source "$DATADIR/$avmdir/datadir.conf" ; echo "$VMIP")"
	    # http://askubuntu.com/questions/441619/how-to-successfully-restart-a-network-without-reboot-over-ssh

	    "$DATADIR/$avmdir/ssh-shortcut.sh" <<EOF
sudo tee -a /etc/network/interfaces <<EOF2

auto eth1
iface eth1 inet static
    address $addr
    netmask 255.255.255.0
EOF2

# sudo ifdown eth1
sudo ifup eth1

EOF
	) ; $iferr_exit

	(
	    $starting_step "Change hostname VM $avmdir"
	    "$DATADIR/$avmdir/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
[[ "\$(hostname)" != *ubuntu* ]]
EOF
	    $skip_step_if_already_done
	    hn=$(
		case "$2" in
		    *main*) echo main ;;
		    *notebook*) echo notebook ;;
		    *) reportfailed "BUG"
		esac
	      )
	    
	    "$DATADIR/$avmdir/ssh-shortcut.sh" <<EOF
echo $hn | sudo tee /etc/hostname
echo 127.0.0.1 $hn | sudo tee -a /etc/hosts
sudo hostname $hn
EOF
	) ; $iferr_exit
    }

    boot-one-vm "$VMDIR" "main KVM" datadir-ci.conf
    boot-one-vm "$VMDIR-notebook" "notebook KVM" datadir-ci-notebook.conf

) ; $iferr_exit
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
) ; $iferr_exit
