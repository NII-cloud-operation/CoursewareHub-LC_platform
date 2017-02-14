#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# check required DATADIR parameters
: "${VPCNAME?}"

# default
: ${cidrblock:="192.168.11.0/24"}

# This script will make sure vpc{keypair,subnet,securitygroup} are set

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
	    awsout="$(aws ec2 create-vpc --cidr-block $cidrblock)"
	    iferr_exit "create-vpc"
	    awsout="${awsout//$remove}"
	    read vpcid therest <<<"${awsout#*VpcId:}"  # parse line w/ "   VpcId: vpc-8f2d81eb "
	    eval_iferr_exit '[[ "'$vpcid'" == vpc-* ]]'
	    aws ec2 create-tags --resources "$vpcid" --tags "Key=vpcname,Value=$VPCNAME"
	    iferr_exit "create-tags"

	    rtinfo="$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpcid" \
                  --query 'RouteTables[].RouteTableId')"
	    rtinfo="${rtinfo//$remove}"  # should be just the route id plus whitespace
	    read -d '' routeid therest <<<"$rtinfo"  # remove the white space
	    eval_iferr_exit '[[ "'$routeid'" == rtb-* ]]'
	    echo "routeid=\"$routeid\"" >> "$DATADIR/datadir.conf"

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
    iferr_exit "describe-subnets"
    # For example, sjson could be:
    # [
    #     "subnet-3aa7cb4c"
    # ]

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    ids=( ${sjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing subnet
	    echo "Using existing subnet: ${ids[0]}"
	    echo "vpcsubnet=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new subnet
	    awsout="$(aws ec2 create-subnet --vpc-id "$vpcid" --cidr-block $cidrblock)"
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
	    reportfailed "More than one subnet has tag with ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit

source "$DATADIR/datadir.conf"

(
    $starting_step "Create Internet Gateway"
    [ "${vpcigw=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    # search for any already attached to the vpc
    sjson="$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpcid" \
                        --query 'InternetGateways[].InternetGatewayId')"
    iferr_exit "describe-igws"
    # For example, sjson could be:
    # [
    #     "igw-3aa7cb4c"
    # ]

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    ids=( ${sjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing igw
	    echo "Using existing igw: ${ids[0]}"
	    echo "vpcigw=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new igw
	    awsout="$(aws ec2 create-internet-gateway)"
	    iferr_exit "create-internet-gateway"
	    awsout="${awsout//$remove}"
	    read igwid therest <<<"${awsout#*InternetGatewayId:}"  # parse line w/ "   InternetGatewayId: igw-fd2d0098 "
	    eval_iferr_exit '[[ "'$igwid'" == igw-* ]]'

	    # next command should have no output, says the amazon doc
	    aws ec2 attach-internet-gateway  --internet-gateway-id "$igwid" --vpc-id "$vpcid"
	    iferr_exit "attach-internet-gateway"

	    ## TODO: Move this out to a separate step
	    awsout2="$(aws ec2 create-route --route-table-id "$routeid" \
                      --destination-cidr-block 0.0.0.0/0 --gateway-id "$igwid")"
	    [[ "$awsout2" == *Return*true* ]] || iferr_exit "create-route"
	    
	    echo "Created new igw: $igwid"
	    echo "vpcigw=\"$igwid\"" >> "$DATADIR/datadir.conf"
	    ;;
	*)
	    reportfailed "More than one internet gateway is already attached to VPC ($vpcid)"
	    ;;
    esac
) ; $iferr_exit

source "$DATADIR/datadir.conf"

(
    $starting_step "Create security group"
    [ "${vpcsecuritygroup=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    sjson="$(aws ec2 describe-security-groups --filters Name=group-name,Values=$VPCNAME --query SecurityGroups[].GroupId )"
    iferr_exit "describe-security-groups"
    # For example, sjson could be:
    # [
    #     "sg-c13aa7a6"
    # ]

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    ids=( ${sjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing security group
	    echo "Using existing security group: ${ids[0]}"
	    echo "vpcsecuritygroup=\"${ids[0]}\"" >> "$DATADIR/datadir.conf"
	;;
	0) # create a new security group
	    awsout="$(aws ec2 create-security-group --group-name "$VPCNAME" --description "allow ssh and jupyter access" --vpc-id "$vpcid")"
	    iferr_exit "create-security-group"
	    awsout="${awsout//$remove}"
	    read sgid therest <<<"${awsout#*GroupId:}"  # parse line w/ "     GroupId: sg-1135a876  "
	    eval_iferr_exit '[[ "'$sgid'" == sg-* ]]'
	    echo "Created new security group: $sgid"
	    for p in 22 80 443; do
		aws ec2 authorize-security-group-ingress --group-id "$sgid" --protocol tcp --port $p --cidr 0.0.0.0/0
	    done
	    # allow all traffic on the private network
	    aws ec2 authorize-security-group-ingress --group-id "$sgid" --protocol all --cidr $cidrblock
	    echo "vpcsecuritygroup=\"$sgid\"" >> "$DATADIR/datadir.conf"
	    ;;
	*)
	    reportfailed "More than one security group named ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit

source "$DATADIR/datadir.conf"

(
    $starting_step "Create keypair"
    [ -f "$DATADIR/sshkey" ]
    $skip_step_if_already_done ; # (no set -e)

    # next command returns error if --keynames does not match anything
    kjson="$(aws ec2 describe-key-pairs --key-names "$VPCNAME" --query KeyPairs[].KeyName 2>/dev/null || :)"
    #### iferr_exit "describe-key-pairs"
    # For example, kjson could be:
    # [
    #     "tensorflow"   ((or whatever $VPCNAME is))
    # ]

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    ids=( ${kjson//$remove} )
    case "${#ids[@]}" in
	1) # use the existing security group
	    echo "Key pair named ($VPCNAME) already exists.  You must"
	    echo "find its private key and copy it to a file named:"
	    echo "     $DATADIR/sshkey"
	    just_exit
	;;
	0) # create a new security group
	    awsout="$(aws ec2 create-key-pair --key-name "$VPCNAME")"
	    iferr_exit "create-key-pair"
	    awsout="${awsout//$remove}"

	    # $awsout contains \n, so the -r option on read is necessary
	    IFS='' read -r line_with_private_key <<<"${awsout#*KeyMaterial:}"  # parse line w/ "  KeyMaterial: ...lots\n.of\n.text... "
	    eval_iferr_exit '[[ "'$line_with_private_key'" == *BEGIN*PRIVATE*END*PRIVATE* ]]'

	    # use printf to convert \n
	    printf -- "${line_with_private_key# }\n" >"$DATADIR/sshkey" ; iferr_exit
	    eval_iferr_exit 'chmod 400 "'$DATADIR/sshkey'"' ; iferr_exit
	    echo "Created new private key"
	    ;;
	*)
	    reportfailed "More than one key pair named ($VPCNAME)"
	    ;;
    esac
) ; $iferr_exit
