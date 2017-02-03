#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

"$DATADIR/vpcproxy/aws-vpc-proxy.sh" wrapped ; $iferr_exit

install_git()
{
    local VMDIR="$1"
    (
	$starting_step "Install git in $VMDIR"
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
}

"$DATADIR/jhvmdir/aws-instance-proxy.sh" wrapped ; $iferr_exit
install_git jhvmdir

for n in hub $node_list; do
    v="jhvmdir-$n"
    "$DATADIR/$v/aws-instance-proxy.sh" wrapped ; $iferr_exit
    install_git "$v"
done

(
    VMDIR="jhvmdir"
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

)
