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

    # extracted with: aws ec2 describe-images --image-ids ami-5dd8b73a
    # but had to delete the "encrypted" tag
    cat >/tmp/modified-mappings.json <<EOF
[
                {
                    "DeviceName": "/dev/sda1", 
                    "Ebs": {
                        "DeleteOnTermination": true, 
                        "SnapshotId": "snap-089b2f07be211d887", 
                        "VolumeSize": 50, 
                        "VolumeType": "gp2"
                    }
                }, 
                {
                    "DeviceName": "/dev/sdb", 
                    "VirtualName": "ephemeral0"
                }, 
                {
                    "DeviceName": "/dev/sdc", 
                    "VirtualName": "ephemeral1"
                }
            ]
EOF
    awsout="$(aws ec2 run-instances --image-id ami-5dd8b73a --count 1 \
        --instance-type c4.xlarge --key-name "$VPCNAME" \
        --block-device-mapping file:///tmp/modified-mappings.json \
	--security-group-ids "$vpcsecuritygroup" --subnet-id "$vpcsubnet"
        )"
    iferr_exit "run-instances"
    echo "$awsout" >> "$DATADIR/awsoutput"
    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    awsout="${awsout//$remove}"
    read instanceid therest <<<"${awsout#*InstanceId:}"  # parse line w/ "   InstanceId: i-0618d5b53b486ba8d "
    echo "instanceid=\"$instanceid\"" >> "$DATADIR/datadir.conf"
    
    read VMIP therest <<<"${awsout#*PrivateIpAddress:}"  # parse line w/ "   PrivateIpAddress: 192.168.11.20 "
    eval_iferr_exit '[ "${VMIP//[^.]}" = "..." ]' # sanity checking for 3 dots
    echo "VMIP=\"$VMIP\"" >> "$DATADIR/datadir.conf"
) ; $iferr_exit

source "$DATADIR/datadir.conf"

(
    $starting_step "Allocate new aws elastic IP address"
    [ "${allocationid=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    # step1: allocate
    awsout="$(aws ec2 allocate-address --domain vpc)"
    iferr_exit "run-instances"
    echo "$awsout" >> "$DATADIR/awsoutput"
    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    awsout="${awsout//$remove}"

    read publicip therest <<<"${awsout#*PublicIp:}"  # parse line w/ "   PublicIp: 54.248.100.146 "
    eval_iferr_exit '[ "${publicip//[^.]}" = "..." ]' # sanity checking for 3 dots
    echo "publicip=\"$publicip\"" >> "$DATADIR/datadir.conf"

    read allocationid therest <<<"${awsout#*AllocationId:}"  # parse line w/ "   AllocationId: eipalloc-d2b8acb7 "
    echo "allocationid=\"$allocationid\"" >> "$DATADIR/datadir.conf"
    eval_iferr_exit '[[ "'$allocationid'" == eipalloc-* ]]'
) ; $iferr_exit

source "$DATADIR/datadir.conf"

(
    $starting_step "Associate new aws elastic IP to ${DATADIR##*/}"
    [ "${associationid=}" != '' ]  # the = is because of set -u
    $skip_step_if_already_done ; # (no set -e)

    # step2: associate
    for i in 1 2 3 4 5 6; do
	echo "Will try associate-address attempt #$i in 10 seconds"
	sleep 10
	awsout2="$(aws ec2 associate-address --instance-id "$instanceid" --allocation-id "$allocationid")"
	rc="$?"
	echo "$awsout2" >> "$DATADIR/awsoutput"
	[ "$rc" = "0" ] && break
    done
    [ "$rc" = "0" ] || just_exit "associate-address: $awsout2"
    # if no success in 6X10 seconds, let outer logic handle it 

    remove='[,\[\]{}"]' # double quotes, commas, braces, and brackets
    awsout2="${awsout2//$remove}"
    read associationid therest <<<"${awsout2#*AssociationId:}"  # parse line w/ "   AssociationId: eipassoc-2bebb745 "
    echo "associationid=\"$associationid\"" >> "$DATADIR/datadir.conf"
    eval_iferr_exit '[[ "'$associationid'" == eipassoc-* ]]'
) ; $iferr_exit

source "$DATADIR/datadir.conf"
