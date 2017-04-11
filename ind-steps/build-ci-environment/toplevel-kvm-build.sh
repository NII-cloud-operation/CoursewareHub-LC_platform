#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

(
    $starting_group "Setup VMs"
    
    "$ORGCODEDIR/kvm-vm-setup.sh" "$DATADIR" wrapped
) ; iferr_exit

(
    $starting_group "Install Jupyternotebook Environment"
    
    "$ORGCODEDIR/build-ci-environment.sh" "$DATADIR" wrapped
) ; iferr_exit
