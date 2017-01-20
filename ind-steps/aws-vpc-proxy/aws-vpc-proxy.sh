#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# check required DATADIR parameters
: "${VPCNAME?}"

# This script will make sure vpc{keypair,subnet} are set

(
    $starting_step "Create VPC"
    [ "${vpckeypair=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    vjson="$(aws ec2 describe-vpcs --filters "Name=tag:vpcname,Values=$VPCNAME" --query 'Vpcs[].VpcId')"
    iferr_exit "describe-vpcs"
    # For example, vjson could be:
    # [
    # "vpc-fe7fdf9a"
    # ]

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    ids=( ${vjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing VPC
	    echo "Using existing VPC: ${ids[0]}"
	    echo "vpckeypair=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new VPC
	    awsout="$(aws ec2 create-vpc --cidr-block 192.168.11.0/24)"
	    awsout="${awsout//$remove}"
	    iferr_exit "create-vpc"
	    read vpcid therest <<<"${awsout#*VpcId:}"  # parse line w/ "   VpcId: vpc-8f2d81eb "
	    eval_iferr_exit '[[ "'$vpcid'" == vpc-* ]]'
	    aws ec2 create-tags --resources "$vpcid" --tags "Key=vpcname,Value=$VPCNAME"
	    iferr_exit "create-tags"
	    echo "Created new VPC: $vpcid"
	    echo "vpckeypair=\"$vpcid\"" >> "$DATADIR/datadir.conf"
	    ;;
	*)
	    reportfailed "More than one VPC has tag with ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit

source "$DATADIR/datadir.conf"
