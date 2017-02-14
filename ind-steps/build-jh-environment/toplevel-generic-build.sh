#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

(
    $starting_step "Setup Instance Dir Information"
    output="$(grep '999\.999' "$DATADIR"/jhvm*/datadir.conf)"
    [ "$output" = "" ]
    $skip_step_if_already_done
    echo "More manual setup is still necessary in the instance directories" 1>&2
    echo "$output" 1>&2
    exit 1
) ; iferr_exit

(
    $starting_group "Install Jupyterhub Environment"
    
    "$ORGCODEDIR/build-jh-environment.sh" "$DATADIR" wrapped
) ; iferr_exit
