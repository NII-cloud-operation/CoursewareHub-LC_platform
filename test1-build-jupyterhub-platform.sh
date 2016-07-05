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

# avoids errors on first run, but maybe not good to change state
# outside of a step
touch "$DATADIR/datadir.conf"

source "$DATADIR/datadir.conf"

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

(
    $starting_group "Setup clean VM for Jupterhub"
    [ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ]
    $skip_group_if_unnecessary
    
    (
	$starting_step "Make vmdir"
	[ -d "$DATADIR/vmdir" ]
	$skip_step_if_already_done ; set -e
	mkdir "$DATADIR/vmdir"
	# increase default mem to give room for a wakame instance or two
	echo ': ${KVMMEM:=4096}' >>"$DATADIR/vmdir/datadir.conf"
    ) ; prev_cmd_failed

    DATADIR="$DATADIR/vmdir" \
	   "$ORGCODEDIR/ind-steps/kvmsteps/kvm-setup.sh" \
	   "$DATADIR/vmimages/centos-7.1.1511-x86_64-base/output/minimal-image.raw.tar.gz"

    "$DATADIR/vmdir/kvm-boot.sh"
    
    (
	$starting_step "Create centos user account"
	[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	    "$DATADIR/vmdir/ssh-to-kvm.sh" [ -d /home/centos ] 2>/dev/null
	}
	$skip_step_if_already_done ; set -e

	"$DATADIR/vmdir/ssh-to-kvm.sh" <<EOF
adduser centos
echo 'centos ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
EOF
    ) ; prev_cmd_failed

	for p in wget bzip2 rsync; do
	    (
		$starting_step "Install $p"
		[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		    [ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ] || \
			[[ "$("$DATADIR/vmdir/ssh-to-kvm.sh" which $p 2>/dev/null)" = *$p* ]]
		}
		$skip_step_if_already_done ; set -e

		"$DATADIR/vmdir/ssh-to-kvm.sh" <<EOF
yum install -y $p
EOF
	    ) ; prev_cmd_failed
	done

) ; prev_cmd_failed


(
    $starting_step "Install Docker"
    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<"which docker" 2>/dev/null 1>&2
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/vmdir/ssh-to-kvm.sh" "curl -fsSL https://get.docker.com/ | sh"
    "$DATADIR/vmdir/ssh-to-kvm.sh" "usermod -aG docker centos"
    "$DATADIR/vmdir/ssh-to-kvm.sh" "service docker start"
    touch "$DATADIR/extrareboot" # necessary to make the usermod take effect in Jupyter environment
) ; prev_cmd_failed

if [ "$extrareboot" != "" ] || \
       [ -f "$DATADIR/extrareboot" ] ; then  # this flag can also be set before calling ./build-nii.sh
    rm -f "$DATADIR/extrareboot"
    [ -x "$DATADIR/vmdir/kvm-shutdown-via-ssh.sh" ] && \
	"$DATADIR/vmdir/kvm-shutdown-via-ssh.sh"
fi

if [ -x "$DATADIR/vmdir/kvm-boot.sh" ]; then
    "$DATADIR/vmdir/kvm-boot.sh"
fi

(  # TODO, redo this the systemd way
    $starting_step "Make sure Docker is started"
    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	out="$("$DATADIR/vmdir/ssh-to-kvm.sh" "service docker status" 2>/dev/null)"
	[[ "$out" == *running* ]]
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/vmdir/ssh-to-kvm.sh" "service docker start"
) ; prev_cmd_failed

(
    $starting_group "Try to load cached Jupyter docker image"
    ! [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
    $skip_group_if_unnecessary

    (
	$starting_step "Load cached jupyter/minimal-notebook image"
	"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
	$skip_step_if_already_done
	# Note: in next line stdin is used for data, not a script to bash
	cat "$DATADIR/jupyter-in-docker-cached.tar.gz" | gunzip - | \
	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c "'docker load'" centos
    )
)

(
    $starting_step "Do docker pull jupyter/minimal-notebook"
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
    $skip_step_if_already_done
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF
docker pull jupyter/minimal-notebook
EOF
)

(
    $starting_step "Save cached Jupyter docker image"
    [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
    $skip_step_if_already_done
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF | gzip - >"$DATADIR/jupyter-in-docker-cached.tar.gz"
set -x
docker save jupyter/minimal-notebook
EOF
)    
