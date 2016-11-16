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
	    tar xSf "$snapshot_source/$VMDIR-snapshot.tar"
	    # snapshot may have been made on another machine, so the
	    # kvmbin setting needs to be redone:
	    sed -i 's,KVMBIN,KVMBINxxx,' "$VMDIR/datadir.conf"
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
    tar xSf "$snapshot_source/extra-snapshot-files.tar"
    echo "..finished."
) ; prev_cmd_failed

(
    $starting_step "Assign mcastPORT"
    [[ "$(cat "$DATADIR"/*/datadir.conf)" != *set-this* ]]
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

    sed -i "s,mcastPORT=set-this-before-booting,mcastPORT=$randomport,"  "$DATADIR"/*vmdir*/datadir.conf
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

# Boot the rest:
"$DATADIR"/jhvmdir/kvm-boot.sh ; prev_cmd_failed
"$DATADIR"/jhvmdir-node1/kvm-boot.sh ; prev_cmd_failed
"$DATADIR"/jhvmdir-node2/kvm-boot.sh ; prev_cmd_failed
"$DATADIR"/jhvmdir-node1/kvm-boot.sh ; prev_cmd_failed
"$DATADIR"/vmdir-1box/kvm-boot.sh ; prev_cmd_failed

VMDIR=jhvmdir  # so code can be copy/pasted from test2-build-nbgrader-environment-w-ansible
(
    $starting_step "Start background-command-processor.sh in background on 192.168.11.88 (hub) VM"
    "$DATADIR/$VMDIR-hub/ssh-to-kvm.sh" <<EOF 2>/dev/null >/dev/null
ps auxwww | grep 'background-command-processo[r]' 1>/dev/null 2>&1
EOF
    $skip_step_if_already_done; set -e
    "$DATADIR/$VMDIR-hub/ssh-to-kvm.sh" <<EOF
set -x
cd /srv
sudo bash -c 'setsid ./background-command-processor.sh 1>>bcp.log 2>&1 </dev/null &'
EOF
) ; prev_cmd_failed

(
    $starting_step "Start background sshuttle on 192.168.11.99 (ansible main) VM"
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF 2>/dev/null >/dev/null
ps auxwww | grep 'sshuttl[e]' 1>/dev/null 2>&1 >/tmp/aa
EOF
    $skip_step_if_already_done; set -e
    # see the step: "Add routing entry for Wakame-vdc's 10.0.2.0/24 network to VM $avmdir"
    "$DATADIR/$VMDIR/ssh-to-kvm.sh" <<EOF
set -x
cat >wakame-sshkey  <<EOF2
$(cat "$DATADIR/vmdir-1box/sshkey")
EOF2
chmod 600 wakame-sshkey
eval \$(ssh-agent -s)
ssh-add wakame-sshkey
ssh-add -l
date
setsid sshuttle -l 0.0.0.0 -r centos@192.168.11.90 10.0.2.0/24 1>>sshuttle.log 2>&1 </dev/null &
sleep 3  # maybe fixes race between setsid and exiting ssh.   TODO: try nohup and more testing
EOF
) ; prev_cmd_failed

(
    $starting_step "Output port forwarding hint script"
    false # just always refresh this
    $skip_step_if_already_done
    httpsport="$(source "$DATADIR"/jhvmdir-hub/datadir.conf ; echo $((VNCPORT + 43 )) )"
    # guess at local IP address
    device="$(cat /proc/self/net/route | \
               while read a b c ; do [ "$b" == 00000000 ] && echo "$a" && break ; done)"
    ipetc="$(ifconfig "$device" | grep -o 'inet [0-9.]*')"

cat /proc/self/net/route | while read a b c ; do [ "$b" == 00000000 ] && echo "$a" && break ; done | ifconfig "$(cat)" | grep -o 'inet [0-9.]*'
    
    tee "$DATADIR"/pfhint.sh <<EOF
# sudo ssh useraccount@127.0.0.1 -L 443:aa.bb.cc.dd:$httpsport -g
# maybe this:
sudo ssh useraccount@127.0.0.1 -L 443:${ipetc#* }:$httpsport -g
echo "Plus do something like echo '127.0.0.1 niidemo.com' >>/etc/hosts"
EOF
) ; prev_cmd_failed
