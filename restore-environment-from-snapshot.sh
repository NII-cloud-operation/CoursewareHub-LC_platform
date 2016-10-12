#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

DATADIR="$(readlink -f "$1")"  # required

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

source "$DATADIR/datadir.conf" || reportfailed

restore_one_vm()
{
    VMDIR="$1"
    (
	$starting_group "Restore VM=$VMDIR"
	[ -d "$DATADIR/$VMDIR" ]
	$skip_group_if_unnecessary

	(
	    $starting_step "Expand snapshot tar file for VM=$VMDIR"
	    [ -f "$DATADIR/$VMDIR-snapshot.tar.gz" ]
	    $skip_step_if_already_done;  set -e

	    echo -n "Expanding tar file..."
	    cd "$DATADIR"
	    tar xSf "$snapshot_source/$VMDIR-snapshot.tar.gz"
	    echo "..finished."
	) ; prev_cmd_failed
    ) ; prev_cmd_failed
}

for i in "${vmlist[@]}"; do
    restore_one_vm "$i"
done

(
    $starting_step "Expand extra-snapshot-files.tar.gz for VM=$VMDIR"
    [ -d "$DATADIR/letsencrypt" ]
    $skip_step_if_already_done;  set -e

    echo -n "Expanding tar file..."
    cd "$DATADIR"
    tar xSf "$snapshot_source/extra-snapshot-files.tar.gz"
    echo "..finished."
) ; prev_cmd_failed

(
    $starting_step "Assign mcastPORT"
    [[ "$(cat "$DATADIR"/*/datadir.conf | tee /tmp/check)" != *set-this* ]]
    $skip_step_if_already_done; set -e

    alreadyset="$(cat "$DATADIR"/*/datadir.conf | grep mcastPORT= | grep -v set-this || true)"
    [ "$alreadyset" = "" ] || reportfailed "Some mcastPORT values (but not all) already set"

    locally_in_use="$(
       ps auxwww | grep -o "mcast=[0-9. ]*:[0-9]*" | cut -d : -f 2 | sort -u
       # e.g.:  "mcast=230.0.0.1:5320" -> "5320" -> sort -u
    )"
    while true; do
	randomport="$(( 5000 + ( $RANDOM % 5000 ) ))"
	if ! grep -Fx "$locally_in_use"  <<<"$randomport" 1>/dev/null ; then
	    break # if $randomport is not in the list
	fi
	sleep 0.567 # save CPU if this loop is buggy
    done
    # TODO, reduce the chance of port conflicts even more, somehow

    sed -i "s,mcastPORT=set-this-before-booting,mcastPORT=$randomport,"  "$DATADIR"/*/datadir.conf
)  ; prev_cmd_failed

(
    $starting_group "Boot and configure hub VM"
    # always do every step
    false
    $skip_group_if_unnecessary

    "$DATADIR"/jhvmdir-hub/kvm-boot.sh ; prev_cmd_failed

    (
	$starting_step "Start restuser daemon"
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<EOF 1>/dev/null 2>&1
ps auxwww | grep 'restuse[r].log'
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<EOF
sudo rmdir /var/run/restuser.sock # for some reason docker puts a directory here by mistake
sudo daemon -n restuser -o /var/log/restuser.log -- python /srv/restuser/restuser.py --skeldir=/srv/skeldir
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Setup keys, restart nginx"
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<'EOF' 1>/dev/null 2>&1
dout="$(sudo docker ps | grep root_nginx_1)"
set -x
exec 2>/tmp/why
[[ "$dout" == *Up* ]]
EOF
	$skip_step_if_already_done; set -e

	# docker mistakenly makes these too, so they must be deleted first
	# (or we may have old keys there)
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo rm -fr /tmp/proxycert /tmp/proxykey
	
	cat "$DATADIR"/letsencrypt/archive/opty.jp/fullchain1.pem | \
	    "$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo tee /tmp/proxycert
	
	cat "$DATADIR"/letsencrypt/archive/opty.jp/privkey1.pem | \
	    "$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo tee /tmp/proxykey
	
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo docker stop root_nginx_1
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo docker start root_nginx_1
    ) ; prev_cmd_failed

) ; prev_cmd_failed
