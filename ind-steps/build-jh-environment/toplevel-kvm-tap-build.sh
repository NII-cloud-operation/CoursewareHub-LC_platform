#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

(
    $starting_group "Setup VMs"
    
    "$ORGCODEDIR/kvm-tap-vm-setup.sh" "$DATADIR" wrapped
) ; iferr_exit

(
    $starting_group "Install Jupyterhub Environment"
    
    "$ORGCODEDIR/build-jh-environment.sh" "$DATADIR" wrapped
) ; iferr_exit
