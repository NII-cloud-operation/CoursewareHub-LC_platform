#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# check required DATADIR parameters
# : 

eval_iferr_exit 'source "$DATADIR/vpc-datadir/datadir.conf"'

(
    $starting_step "Run instance for ${DATADIR##*/}"
    [ "${instanceid=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    # check that these have been set by vpc-datadir:
    : ${VPCNAME?} ${vpcsecuritygroup?}  ${vpcsubnet?}
    # TODO: is it enough just to just let "set -u" *and* iferr_exit catch these?
    
    awsout="$(aws ec2 run-instances --image-id ami-5dd8b73a --count 1 \
        --instance-type t2.micro --key-name "$VPCNAME" \
	--security-group-ids "$vpcsecuritygroup" --subnet-id "$vpcsubnet"
        )"
    iferr_exit "run-instances"
    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    awsout="${awsout//$remove}"
    read instanceid therest <<<"${awsout#*InstanceId:}"  # parse line w/ "   InstanceId: i-0618d5b53b486ba8d "
    echo "instanceid=\"$instanceid\"" >> "$DATADIR/datadir.conf"
) ; $iferr_exit

source "$DATADIR/datadir.conf"
