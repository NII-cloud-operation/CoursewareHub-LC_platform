#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# check required DATADIR parameters
: "${VPCNAME?}"

# This script will make sure vpc{keypair,subnet} are set

(
    $starting_step "Create VPC"
    [ "${vpckeypair=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; set -e

    vjson="$(aws ec2 describe-vpcs --filters "Name=tag:vpcname,Values=$VPCNAME" --query 'Vpcs[].VpcId')"
    # For example, vjson could be:
    # [
    # "vpc-fe7fdf9a"
    # ]

    remove='[\[\]"]' # double quotes and brackets
    ids=( ${vjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing VPC
	    echo "vpckeypair=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new VPC
	    reportfailed TODO
	    ;;
	*)
	    reportfailed "More than one VPC has tag with ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit

source "$DATADIR/datadir.conf"
