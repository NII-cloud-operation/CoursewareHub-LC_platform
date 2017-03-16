#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

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

) ; $iferr_exit
exit
