#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

DATADIR="$(readlink -f "$1")"  # required

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

[ -f "$DATADIR/flag-inital-build-completed" ] || reportfailed "build must be completed before running this"


# It is important that node1 and node2 be shutdown before hub, because
# stopping the NFS server on the hub will freeze the node1 and node2 and
# prevent them from doing a clean shutdown.

vmlist=(
    jhvmdir-node1
    jhvmdir-node2
    jhvmdir
    jhvmdir-hub
    vmdir-1box
)

TARSUFFIX=".tar"
TARPARAMS="cSf"

do_one_vm()
{
    VMDIR="$1"
    (
	$starting_group "Checkpoint VM=$VMDIR"
	[ -f "$DATADIR/$VMDIR-snapshot$TARSUFFIX" ]
	$skip_group_if_unnecessary

	"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh"

	(
	    $starting_step "Create snapshot tar file for VM=$VMDIR"
	    [ -f "$DATADIR/$VMDIR-snapshot$TARSUFFIX" ]
	    $skip_step_if_already_done;  set -e

	    cp "$DATADIR/$VMDIR/datadir.conf" "$DATADIR/$VMDIR/datadir.conf.save"
	    sed -i 's,mcastPORT=.*$,mcastPORT=set-this-before-booting,' "$DATADIR/$VMDIR/datadir.conf"

	    echo -n "Creating tar file..."
	    cd "$DATADIR"
	    tar $TARPARAMS "$DATADIR/$VMDIR-snapshot$TARSUFFIX" "$VMDIR"
	    echo "..finished."

	    cp "$DATADIR/$VMDIR/datadir.conf.save" "$DATADIR/$VMDIR/datadir.conf"
	) ; prev_cmd_failed
    ) ; prev_cmd_failed
}

for i in "${vmlist[@]}"; do
    do_one_vm "$i"
done

(
    $starting_step "Snapshot extra files used when restoring"
    [ -f "$DATADIR/extra-snapshot-files$TARSUFFIX" ]
    $skip_step_if_already_done; set -e
    extrafiles=(
	bin
	demo-scripts
	letsencrypt
	test2-build-nbgrader-environment-w-ansible
    )
    cd "$DATADIR"
    tar $TARPARAMS "$DATADIR/extra-snapshot-files$TARSUFFIX" "${extrafiles[@]}"
)  ; prev_cmd_failed
