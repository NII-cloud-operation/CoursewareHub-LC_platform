#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

## This script assumes link to ubuntu image is already at
## the location set by kvm-bm-setup.sh-new.

VMDIR=civmdir

(
    $starting_group "Basic setup for the CI VM"

    # So far it does not take long to rebuild the whole CI VM, so
    # there is no snapshot made

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
	$starting_step "Install git, jq and supervisor"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which git && which jq && which supervisorctl
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
sudo apt-get update
sudo apt-get -y install git jq supervisor
EOF
    ) ; $iferr_exit

    # Having something from *.{net,com,...} here seems to make outgoing mail work better.
    # And seems that command "host civm.axsh.net", for example, should return "mail is handled by"
    # in the output.  If so, sending mail from the VM becomes demoable.
    # TODO: Research the proper way to configure hostname/sendmail for various target
    # environments.
    : ${vmhostname:=civm.axsh.net}

    (
	$starting_step "Change hostname VM $VMDIR"
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
[[ "\$(hostname)" != *ubuntu* ]]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
echo $vmhostname | sudo tee /etc/hostname
echo 127.0.0.1 $vmhostname | sudo tee -a /etc/hosts
sudo hostname $vmhostname
EOF
    ) ; $iferr_exit

    (
	$starting_step "Install mailutils"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which mail
EOF
	$skip_step_if_already_done ; set -e

	# https://stackoverflow.com/questions/15469343/installing-mailutils-using-apt-get-without-user-intervention
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
sudo debconf-set-selections <<< "postfix postfix/mailname string $vmhostname"
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo apt-get install -y mailutils
EOF
    ) ; $iferr_exit

    (
	$starting_step "Install sendmail"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which which sendmail
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
sudo apt-get install -y sendmail
EOF
    ) ; $iferr_exit
) ; $iferr_exit
