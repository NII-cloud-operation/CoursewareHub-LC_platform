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

# one fuction to handle both local and remove kvms
runonvm()
{
    local avmpath="$1"
    if [ -f "$avmpath/proxy-shell.sh" ]; then
	"$avmpath/proxy-shell.sh"
    else
	( cd "$avmpath" &&  bash	) || return 1
    fi
}

(
    $starting_group "Extra memory and cpus"
    false
    $skip_group_if_unnecessary

    do1_moremem()
    (
	avmdir="$1"
	$starting_step "More memory for $avmdir"
	output="$(runonvm "$DATADIR/$avmdir" <<<'grep KVMMEM datadir.conf')"
	[[ "$output" == *KVMMEM=16384* ]]
	$skip_step_if_already_done;  set -e
	runonvm "$DATADIR/$avmdir" <<<'[ -f datadir.conf ]' #sanity check
	runonvm "$DATADIR/$avmdir" <<<'echo "KVMMEM=16384" >>datadir.conf'
    ) ; prev_cmd_failed

    do1_morecpu()
    (
	avmdir="$1"
	$starting_step "More cpus for $avmdir"
	output="$(runonvm "$DATADIR/$avmdir" <<<'grep -F -e "-smp" kvm-boot.sh')"
	[[ "$output" == *-smp\ 8* ]]
	$skip_step_if_already_done;  set -e
	runonvm "$DATADIR/$avmdir" <<<'[ -f datadir.conf ]' #sanity check
	runonvm "$DATADIR/$avmdir" <<<'sed -i "s,-smp [0-9]*,-smp 8," kvm-boot.sh'
    ) ; prev_cmd_failed

    for i in "${vmlist[@]}"; do
	do1_morecpu "$i" ; prev_cmd_failed
	do1_moremem "$i" ; prev_cmd_failed
    done
) ; prev_cmd_failed

(
    $starting_group "Setup hub for networking using qemu socket"
    false
    $skip_group_if_unnecessary

    (
	avmdir=jhvmdir-hub
	$starting_step "Patch hub's kvm-boot.sh"
	output="$(runonvm "$DATADIR/$avmdir" <<<'grep -F -e "mcastnet" kvm-boot.sh')"
	[[ "$output" == *mcastnet*extra-kvm-net.sh* ]]
	$skip_step_if_already_done
	runonvm "$DATADIR/$avmdir" <<<'sed -i "s/,addr=.*$//" kvm-boot.sh'  # because extra nics confict with preassigned pci slots
	runonvm "$DATADIR/$avmdir" <<<'sed -i "s,mcastnet$,mcastnet \$(source extra-kvm-net.sh)," kvm-boot.sh'
    ) ; prev_cmd_failed

    (
	avmdir=jhvmdir-hub
	$starting_step "Add kvm nics to hub that listen on sockets"
	runonvm "$DATADIR/$avmdir" <<<'[ -f extra-kvm-net.sh ]'
	$skip_step_if_already_done
	## a triple nested heredoc!  TODO: double check this, maybe rewrite
	runonvm "$DATADIR/$avmdir" <<EOF
cat >extra-kvm-net.sh <<'EOF2'
cat <<EOFsourced
$(
    vvv=2
    for i in "${vmlist[@]}"; do
        [[ $i == *node* ]] || continue
        newmac="52:54:00:12:50:$(( 10 + vvv ))"
        echo
        echo "-net nic,vlan=$vvv,macaddr=$newmac"
        # ports 50 thru 79 are maybe free
        echo "-net socket,vlan=$vvv,listen=:\$(( VNCPORT + 50 + $vvv ))"
        (( vvv++ ))
    done
)
EOFsourced
EOF2
EOF
    ) ; prev_cmd_failed
) ; prev_cmd_failed


(
    $starting_group "Setup nodes for networking using qemu socket"
    false
    $skip_group_if_unnecessary

    do1_patchnode_bootscript()
    (
	# this is similar to the "Patch hub's..." step above, except that $mcastnet var is removed
	avmdir="$1"
	$starting_step "Patch kvm-boot.sh of node $avmdir"
	output="$(runonvm "$DATADIR/$avmdir" <<<'grep -F -e "extra-kvm" kvm-boot.sh')"
	[[ "$output" == *extra-kvm-net.sh* ]]
	$skip_step_if_already_done
	runonvm "$DATADIR/$avmdir" <<<'sed -i "s,mcastnet$,(source extra-kvm-net.sh)," kvm-boot.sh'
    ) ; prev_cmd_failed

    # extra-kvm-net.sh could use cat instead of source, because there are no expansions,
    # but keeping it as source to be the same as the code for the hub VM
    
    do1_node_socketnic()
    (
	avmdir="$1"
	nodenumber="${avmdir#jhvmdir-node}"
	$starting_step "Add kvm nics to hub that listen on sockets"
	runonvm "$DATADIR/$avmdir" <<<'[ -f extra-kvm-net.sh ]'
	$skip_step_if_already_done

	HUBVNCPORT="$(
runonvm "$DATADIR/jhvmdir-hub" <<'EOF'
source datadir.conf
echo $VNCPORT
EOF
)"
	
	HUBIP="$(
runonvm "$DATADIR/jhvmdir-hub" <<'EOF'
getipaddress()
{
    read -a line1array <<<"$(ip route get 8.8.8.8)"
    # something like: ( 8.8.8.8 via 157.1.207.254 dev bond0  src 157.1.207.248 )
    echo "${line1array[@]: -1}" # last token, the space is necessary
}
getipaddress
EOF
)"
	echo "HUBIP=$HUBIP  HUBVNCPORT=$HUBVNCPORT"
	
	## a triple nested heredoc!  TODO: double check this, maybe rewrite
	runonvm "$DATADIR/$avmdir" <<EOF
cat >extra-kvm-net.sh <<'EOF2'
cat <<EOFsourced
$(
    newmac="52:54:00:12:51:$(( 10 + nodenumber + 1 ))"
    echo
    echo "-net nic,vlan=1,macaddr=$newmac"
    echo "-net socket,vlan=1,connect=$HUBIP:\$(( $HUBVNCPORT + 51 + $nodenumber ))"
)
EOFsourced
EOF2
EOF
    ) ; prev_cmd_failed

    for i in "${vmlist[@]}"; do
	[[ "$i" == *node* ]] || continue
	do1_patchnode_bootscript "$i" ; prev_cmd_failed
	do1_node_socketnic "$i" ; prev_cmd_failed
    done

) ; prev_cmd_failed
