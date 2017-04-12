#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

[ -f "$DATADIR/flag-inital-build-completed" ] || reportfailed "build must be completed before running this"

[ "$node_list" != "" ] || reportfailed "node_list not defined"

# It is important that node1, node2, etc be shutdown before hub, because
# stopping the NFS server on the hub will freeze the node VMs and
# prevent them from doing a clean shutdown.

vmlist=(
    $(
	for i in $node_list; do
	    echo jhvmdir-$i
	done
    )
    jhvmdir
    jhvmdir-hub
)

TARSUFFIX=".tar"
TARPARAMS="cSf"

: ${bridgeNAME:=''} # for set -u, in case not in datadir.conf

do_one_vm()
{
    VMDIR="$1"
    (
	$starting_group "Checkpoint VM=$VMDIR"
	[ -f "$DATADIR/$VMDIR-snapshot$TARSUFFIX" ]
	$skip_group_if_unnecessary

	"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" wrapped ; $iferr_exit

	(
	    $starting_step "Create snapshot tar file for VM=$VMDIR"
	    [ -f "$DATADIR/$VMDIR-snapshot$TARSUFFIX" ]
	    $skip_step_if_already_done;  set -e

	    if [ "$bridgeNAME" == "" ]; then
		cp "$DATADIR/$VMDIR/datadir.conf" "$DATADIR/$VMDIR/datadir.conf.save"
		sed -i 's,mcastPORT=.*$,mcastPORT=set-this-before-booting,' "$DATADIR/$VMDIR/datadir.conf"
	    fi

	    echo -n "Creating tar file..."
	    cd "$DATADIR"
	    tar $TARPARAMS "$DATADIR/$VMDIR-snapshot$TARSUFFIX" "$VMDIR"
	    echo "..finished."

	    cp "$DATADIR/$VMDIR/datadir.conf.save" "$DATADIR/$VMDIR/datadir.conf"
	) ; $iferr_exit
    ) ; $iferr_exit
}

for i in "${vmlist[@]}"; do
    do_one_vm "$i"
done
