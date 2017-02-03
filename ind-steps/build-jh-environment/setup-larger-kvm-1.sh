#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# It seems that when the source above sources datadir.conf, this line
# is not done correctly:
#    "declare -a 'vmlist=([0]="jhvmdir-hub" [1]="jhvmdir" [2]="jhvmdir-node1" [3]="jhvmdir-node2")'"
# such that set -u makes "${vmlist[@]}" flag an error.  So
# loading it again directly from this file:
source "$DATADIR/datadir.conf"

# TODO: figure out the above bash bug/oddity

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
    ) ; $iferr_exit

    do1_morecpu()
    (
	avmdir="$1"
	$starting_step "More cpus for $avmdir"
	output="$(runonvm "$DATADIR/$avmdir" <<<'grep -F -e "-smp" kvm-boot.sh')"
	[[ "$output" == *-smp\ 8* ]]
	$skip_step_if_already_done;  set -e
	runonvm "$DATADIR/$avmdir" <<<'[ -f datadir.conf ]' #sanity check
	runonvm "$DATADIR/$avmdir" <<<'sed -i --follow-symlinks "s,-smp [0-9]*,-smp 8," kvm-boot.sh'
    ) ; $iferr_exit

    for i in "${vmlist[@]}"; do
	do1_morecpu "$i" ; $iferr_exit
	do1_moremem "$i" ; $iferr_exit
    done
) ; $iferr_exit
