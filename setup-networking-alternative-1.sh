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
	( cd "$avmpath" &&  bash	) || exit
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
