#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

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
	runonvm "$DATADIR/$avmdir" <<<'sed -i "s,-smp [0-9]*,-smp 8," kvm-boot.sh'
    ) ; $iferr_exit

    for i in "${vmlist[@]}"; do
	do1_morecpu "$i" ; $iferr_exit
	do1_moremem "$i" ; $iferr_exit
    done
) ; $iferr_exit
