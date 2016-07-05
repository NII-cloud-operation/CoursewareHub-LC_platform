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
    $starting_group "Setup clean VM for Jupterhub"
    [ -f "$DATADIR/$VMDIR/minimal-image-w-jupyter.raw.tar.gz" ]
    $skip_group_if_unnecessary
    
    (
	$starting_step "Make $VMDIR"
	[ -d "$DATADIR/$VMDIR" ]
	$skip_step_if_already_done ; set -e
	mkdir "$DATADIR/$VMDIR"
	# increase default mem to give room for a wakame instance or two
	echo ': ${KVMMEM:=4096}' >>"$DATADIR/$VMDIR/datadir.conf"
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
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" [ -d /home/centos ] 2>/dev/null
	}
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
adduser centos
echo 'centos ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
EOF
    ) ; prev_cmd_failed

	for p in wget bzip2 rsync nc netstat strace lsof; do
	    (
		$starting_step "Install $p"
		[ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
		    [ -f "$DATADIR/$VMDIR/minimal-image-w-jupyter.raw.tar.gz" ] || \
			[[ "$("$DATADIR/$VMDIR/ssh-to-kvm.sh" which $p 2>/dev/null)" = *$p* ]]
		}
		$skip_step_if_already_done ; set -e
		package=$p
		[ "$p" = "netstat" ] && package=net-tools
		"$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
yum install -y $p
EOF
	    ) ; prev_cmd_failed
	done

) ; prev_cmd_failed


(
    $starting_step "Install Docker"
    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" su -l -c bash centos <<<"which docker" 2>/dev/null 1>&2
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "curl -fsSL https://get.docker.com/ | sh"
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "usermod -aG docker centos"
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "service docker start"
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

(  # TODO, redo this the systemd way
    $starting_step "Make sure Docker is started"
    [ -x "$DATADIR/$VMDIR/ssh-to-kvm.sh" ] && {
	out="$("$DATADIR/$VMDIR/ssh-to-kvm.sh" "service docker status" 2>/dev/null)"
	[[ "$out" == *running* ]]
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" "service docker start"
) ; prev_cmd_failed

(
    $starting_group "Try to load cached Jupyter docker image"
    ! [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
    $skip_group_if_unnecessary

    (
	$starting_step "Load cached jupyter/minimal-notebook image"
	"$DATADIR/$VMDIR/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
	$skip_step_if_already_done
	# Note: in next line stdin is used for data, not a script to bash
	cat "$DATADIR/jupyter-in-docker-cached.tar.gz" | gunzip - | \
	    "$DATADIR/$VMDIR/ssh-to-kvm.sh" su -l -c "'docker load'" centos
    ) ; prev_cmd_failed
) ; prev_cmd_failed

(
    $starting_step "Do docker pull jupyter/minimal-notebook"
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
    $skip_step_if_already_done
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" su -l -c bash centos <<EOF
docker pull jupyter/minimal-notebook
EOF
) ; prev_cmd_failed

(
    $starting_step "Save cached Jupyter docker image"
    [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
    $skip_step_if_already_done
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" su -l -c bash centos <<EOF | gzip - >"$DATADIR/jupyter-in-docker-cached.tar.gz"
set -x
docker save jupyter/minimal-notebook
EOF
) ; prev_cmd_failed
