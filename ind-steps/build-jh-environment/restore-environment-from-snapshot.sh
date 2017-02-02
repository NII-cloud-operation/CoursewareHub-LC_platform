#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

DATADIR="$(readlink -f "$1")"  # required

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

source "$DATADIR/datadir-jh.conf" || reportfailed

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
	$starting_step "Create create br0 on hub"
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<'EOF' 1>/dev/null 2>&1
ip link show br0 && [[ "$(ifconfig br0)" == *192.168.11.88* ]]
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<EOF
sudo apt-get install bridge-utils
sudo brctl addbr br0
sudo ifconfig br0 up 192.168.11.88
EOF
    ) ; prev_cmd_failed

    (
	$starting_step "Add all eth* (except eth0) devices to bridge br0"
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<'EOF' 1>/dev/null 2>&1
ip link | (
   while IFS=': ' read count device rest ; do
      [ "$device" = "eth0" ] && continue
      [[ "$device" != eth* ]] && continue
      [[ "$rest" == *\ br0\ * ]] || exit 1
   done
   exit 0
)
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<'EOF'
set -e
set -x
ip link | while IFS=': ' read count device rest ; do
             [ "$device" = "eth0" ] && continue
             [[ "$device" != eth* ]] && continue
             [[ "$rest" == *\ br0\ * ]] && continue
             sudo brctl addif br0 "$device"
             sudo ifconfig "$device" up 0.0.0.0
          done
EOF
    ) ; prev_cmd_failed

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

    (
	$starting_step "Make sure root_jupyterhub_1 container is running"
	# This step is a workaround. It should be running by now, but
	# sometimes it is not, not sure why.
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh <<'EOF' 1>/dev/null 2>&1
dout="$(sudo docker ps | grep root_jupyterhub_1)"
set -x
exec 2>/tmp/why
[[ "$dout" == *Up* ]]
EOF
	$skip_step_if_already_done; set -e

	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo docker stop root_jupyterhub_1
	"$DATADIR"/jhvmdir-hub/ssh-to-kvm.sh sudo docker start root_jupyterhub_1
    ) ; prev_cmd_failed

) ; prev_cmd_failed

# Boot the rest:
for vm in "${vmlist[@]}"; do
    # no problem that hub is already booted
    "$DATADIR"/$vm/kvm-boot.sh ; prev_cmd_failed
done

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
