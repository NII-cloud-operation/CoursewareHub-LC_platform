#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

DATADIR="$1"

[ -L "$1/build-jh-environment.sh" ] || reportfailed "First parameter must be the datadir"

DATADIR="$(readlink -f "$DATADIR")"

source "$DATADIR/datadir.conf" || reportfailed

source "$ORGCODEDIR/../../simple-defaults-for-bashsteps.source" || reportfailed

(
    $starting_group "Setup VMs"
    
    "$ORGCODEDIR/kvm-vm-setup.sh" "$DATADIR"
) ; prev_cmd_failed

(
    $starting_group "Install Jupyterhub Environment"
    
    "$ORGCODEDIR/build-jh-environment.sh" "$DATADIR"
) ; prev_cmd_failed
