#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# check required DATADIR parameters
: "${VPCNAME?}"

# This script will make sure vpc{keypair,subnet} are set

(
    $starting_step "Create VPC"
    [ "${vpcid=}" != '' ]  # the = is because of set -u
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
	    echo "vpcid=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new VPC
	    awsout="$(aws ec2 create-vpc --cidr-block 192.168.11.0/24)"
	    iferr_exit "create-vpc"
	    awsout="${awsout//$remove}"
	    read vpcid therest <<<"${awsout#*VpcId:}"  # parse line w/ "   VpcId: vpc-8f2d81eb "
	    eval_iferr_exit '[[ "'$vpcid'" == vpc-* ]]'
	    aws ec2 create-tags --resources "$vpcid" --tags "Key=vpcname,Value=$VPCNAME"
	    iferr_exit "create-tags"
	    echo "Created new VPC: $vpcid"
	    echo "vpcid=\"$vpcid\"" >> "$DATADIR/datadir.conf"
	    ;;
	*)
	    reportfailed "More than one VPC has tag with ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit

source "$DATADIR/datadir.conf"

(
    $starting_step "Create Subnet"
    [ "${vpcsubnet=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    sjson="$(aws ec2 describe-subnets --filters "Name=tag:vpcname,Values=$VPCNAME" --query 'Subnets[].SubnetId')"
    iferr_exit "describe-vpcs"
    # For example, sjson could be:
    # [
    #     "subnet-3aa7cb4c"
    # ]

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    ids=( ${sjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing VPC
	    echo "Using existing subnet: ${ids[0]}"
	    echo "vpcsubnet=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new VPC
	    awsout="$(aws ec2 create-subnet --vpc-id "$vpcid" --cidr-block 192.168.11.0/24)"
	    iferr_exit "create-subnet"
	    awsout="${awsout//$remove}"
	    read subnetid therest <<<"${awsout#*SubnetId:}"  # parse line w/ "   SubnetId: subnet-5723920f "
	    eval_iferr_exit '[[ "'$subnetid'" == subnet-* ]]'
	    aws ec2 create-tags --resources "$subnetid" --tags "Key=vpcname,Value=$VPCNAME"
	    iferr_exit "create-tags"
	    echo "Created new subnet: $subnetid"
	    echo "vpcsubnet=\"$subnetid\"" >> "$DATADIR/datadir.conf"
	    ;;
	*)
	    reportfailed "More than one VPC has tag with ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit
