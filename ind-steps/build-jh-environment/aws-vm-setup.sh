#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

"$DATADIR/vpcproxy/aws-vpc-proxy.sh" wrapped ; $iferr_exit

install_git_etc()
{
    local VMDIR="$1"
    (
	$starting_step "Install git in $VMDIR"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
apt list --installed | grep linux-image-extra || exit 1
which git || exit 1
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
sudo apt-get update
# from https://gist.github.com/ferrouswheel/d17da01b110308db896e
sudo apt-get -y install linux-image-extra-\$(uname -r)

# The linux-image-extra is so docker will use aufs.  Otherwise, docker
# uses devicemapper, which has race conditions with udev
# https://github.com/docker/docker/issues/4036

sudo apt-get -y install git 
EOF
    ) ; $iferr_exit
}

aws_ubuntu_root()
{
    local VMDIR="$1"
    (
	$starting_step "Make root ssh key on AWS ubuntu normal"
	# otherwise root ssh login is disabled with this message:
	# >>  Please login as the user "ubuntu" rather than the user "root".
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" sudo bash <<'EOF' 2>/dev/null 1>/dev/null
[[ "$(cat /root/.ssh/authorized_keys)" != *command* ]]
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" sudo bash <<'EOF'
cat /home/ubuntu/.ssh/authorized_keys >/root/.ssh/authorized_keys
EOF
    ) ; $iferr_exit
}

"$DATADIR/jhvmdir/aws-instance-proxy.sh" wrapped ; $iferr_exit
install_git_etc jhvmdir

for n in hub $node_list; do
    v="jhvmdir-$n"
    "$DATADIR/$v/aws-instance-proxy.sh" wrapped ; $iferr_exit
    install_git_etc "$v"
    aws_ubuntu_root "$v"
done
