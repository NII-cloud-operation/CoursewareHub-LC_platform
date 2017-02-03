#!/bin/bash

source "$(dirname "$0")/bashsteps-bash-utils-jan2017.source"

source "$LINKCODEDIR/datadir.conf" || iferr_exit

extraoptions=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o GSSAPIAuthentication=no
    )

## TODO, better error checking, etc.

ssh "${extraoptions[@]}" "ubuntu@$publicip" -i "$LINKCODEDIR/vpc-datadir/pkey" "$@"


