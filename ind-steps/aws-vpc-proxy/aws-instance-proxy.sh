#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# check required DATADIR parameters
# : 

eval_iferr_exit 'source "$DATADIR/vpc-datadir/datadir.conf"'

(
    $starting_step "Run instance for ${DATADIR##*/}"
    [ "${instanceid=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    aws ec2 run-instances --image-id ami-5dd8b73a --count 1 \
        --instance-type t2.micro --key-name "$VPCNAME" \
	--security-group-ids "$vpcsecuritygroup" --subnet-id "$vpcsubnet"

    just_exit "more TODO here"
) ; $iferr_exit

source "$DATADIR/datadir.conf"
