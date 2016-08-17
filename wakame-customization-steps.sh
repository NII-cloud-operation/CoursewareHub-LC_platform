
# much in this file was copy/pasted from here:
# https://github.com/axsh/nii-project-2016/blob/master/build-nii.sh

# plus sed 's,/vmdir/,/vmdir-1box/,'

DATADIR="$1" # workaround, if DATADIR is exported, it messes up kvmsteps.  TODO: fix this.

(
    $starting_group "Customize Wakame"

    # function is called remotely in the next step below
    do_register_keypair()
    {
	cat <<'EOS' > mykeypair
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA6KmXs11l/2WUIBDYmTB0T+BXwwCXT+RP/CTVtxq1Tnq8biwa
pDxHuYgvQWSOOH7DIZq/+GU+P69BBWAbnd1LNkWDOoMmnaIthXQBptZupYFfYiKA
Uh4UH0L0wwenifE2yV+SdWLT6FEiiQ2RTatqK1xiWSwvduWkeMA+dW1NbSk0XmEh
Z76QLsRxrs9JF4jqPXJVulzgjnD9Z5tkNY7MyfD1PNJcM2+MS8XmAApxLQLrfxEl
LZMsgvzvFVec45siOiG+VTWbGADc3lBSHIj2pt6aZDLkOhSnZegmsciVFQk1ulLF
jGjD2LoqYT5/UirpwQsElsjWTEEbBZzV10AVlwIDAQABAoIBAQCdnQ4cv1/ypXC0
TFU/abjRx8wMWWEoCSY6TQXOtjQvByyRgiVGL2PzhxNkPGewVAeCw1/bOVLzN5lX
t+Tdi+WAzZR51hEZ5pzp9E2OJWPtkPf59h9yAdhl2SkQ2iWgaB1STAFermWZ0yUP
LXbK5B3XZA1oFWvOIwHJn4pwaGx0TpOtEjPHiEkJxj1SRAzN377Uu3SNz9UsRrfQ
3v7iLxrPvwqhXIBo1VzQIliWzH5/IQ6xAqAsMLTo0uJ+d1wkoZ6nGkjt+LYD5hyD
Ov76lOjlevkPu3BENwwt3Este2d00gOC2Qt649P/chd9B8vc4ZZ8F3bPVfmfdiJt
fYRPaF5ZAoGBAP5vEA/lWH5xN6dB7j+wFPLAP7+8H2jz4aBcDWCiDjoMA4JRvc8V
gJxaW33b8gbP39byZAfBLNWHPE+4q/95CW7TkXnzdCR9HxeKC77jnBXg6wX5zist
E/cDMPykATtMqUFf/K46lPjaUbn4gmLEkc9lS7V+ySoPMdMUG6zqQf2DAoGBAOoY
OPSHu2Y7R4V3BnzNeGz6PCrohz7IjqjSD74KhAhuFCM7w+ymDmk2xSIR4S4F7qlD
mBodXpncqxQMtkF2pRRGDefbTXW5m+lWOy/DrsYV0bqy5OqA2r7Ukj5M0o97S8D1
vhTxwXCehx8GX8RlbybuMkfpB2NefMxakG+BAX9dAoGASPS/vk8dGOSN+L/G+Swc
VZ8aqHfg6c9Emx7KFzNgsPRQ7UVTD9YykqK2KViwBZQFszS9yhtyJ6gnexSQ/ShP
tB+mTzmny+60w6Mpywqo7v0XZxdCLs82MlYP7eF5GO/aeIx1f9/8Z37ygEjp2jhT
NwzssJYySIUi3Eufw+1IDtECgYEAr3NOJMAiTWH6neZyn1Fkg9EdDU/QJdctTQx7
rgS1ppfSUgH2O0TOIj9hisJ50gOyN3yo4FHI2GrScimA5BmnakWDIJZ2PNjLKRxv
KcJxGJe75EE2XygKSuKJZVYwrkdLpKjKOWpkgCLgxPkDB/C6WSRH3SujVO+5e3QZ
MukulSUCgYBMtuQ6VMrlMTedLW6ryd8VYsVNZaAGuphejFCCuur13M/1wHrRUzqM
hECAngl6fus+weYMiQYx1V8oxz3tBdYO8KKG8pnQySTt5Dln19+vqH2+18RWDKtH
0rwxRJ4Rc3wKFVwK+gz6NsBvftnQAK52qWip71tPY7zt9LeWWJv08g==
-----END RSA PRIVATE KEY-----
EOS
	chmod 600 mykeypair

	cat <<'EOS' > mykeypair.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDoqZezXWX/ZZQgENiZMHRP4FfDAJdP5E/8JNW3GrVOerxuLBqkPEe5iC9BZI44fsMhmr/4ZT4/r0EFYBud3Us2RYM6gyadoi2FdAGm1m6lgV9iIoBSHhQfQvTDB6eJ8TbJX5J1YtPoUSKJDZFNq2orXGJZLC925aR4wD51bU1tKTReYSFnvpAuxHGuz0kXiOo9clW6XOCOcP1nm2Q1jszJ8PU80lwzb4xLxeYACnEtAut/ESUtkyyC/O8VV5zjmyI6Ib5VNZsYANzeUFIciPam3ppkMuQ6FKdl6CaxyJUVCTW6UsWMaMPYuiphPn9SKunBCwSWyNZMQRsFnNXXQBWX knoppix@Microknoppix
EOS

	/opt/axsh/wakame-vdc/dcmgr/bin/vdc-manage keypair add \
						  --uuid ssh-cicddemo \
						  --account-id a-shpoolxx \
						  --private-key mykeypair \
						  --public-key mykeypair.pub \
						  --description cicddemo \
						  --service-type std \
						  --display-name cicddemo
    } # end of register_hva() function

    (
	$starting_step "Install sshkey into Wakame-vdc database"
	echo "select * from ssh_key_pairs; " | \
	    "$DATADIR/vmdir-1box/ssh-to-kvm.sh" mysql -u root wakame_dcmgr 2>/dev/null | \
	    grep cicddemo >/dev/null
	$skip_step_if_already_done
	(
	    declare -f do_register_keypair
	    echo do_register_keypair
	) | bash -x "$DATADIR/vmdir-1box/ssh-to-kvm.sh"
	# this step was adapted from code at:
	# https://github.com/axsh/nii-image-and-enshuu-scripts/blob/changes-for-the-2nd-class/wakame-bootstrap/wakame-vdc-install-hierarchy.sh#L426-L477
    ) ; prev_cmd_failed
    
    (
	$starting_step "Install security group into Wakame-vdc database"
	echo "select * from security_groups; " | \
	    "$DATADIR/vmdir-1box/ssh-to-kvm.sh" mysql -u root wakame_dcmgr 2>/dev/null | \
	    grep cicddemo >/dev/null
	$skip_step_if_already_done
	"$DATADIR/vmdir-1box/ssh-to-kvm.sh" \
	    /opt/axsh/wakame-vdc/dcmgr/bin/vdc-manage securitygroup add \
	    --uuid sg-cicddemo \
	    --account-id a-shpoolxx \
	    --description cicddemo \
	    --service-type std \
	    --display-name cicddemo \
	    --rule - <<EOS
icmp:-1,-1,ip4:0.0.0.0/0
tcp:22,22,ip4:0.0.0.0/0
tcp:80,80,ip4:0.0.0.0/0
tcp:8080,8080,ip4:0.0.0.0/0
EOS
	# this step was adapted from code at:
	# https://github.com/axsh/nii-image-and-enshuu-scripts/blob/changes-for-the-2nd-class/wakame-bootstrap/wakame-vdc-install-hierarchy.sh#L486-L506
    ) ; prev_cmd_failed

    (
	$starting_step "Hack Wakame-vdc to always set openvz's privvmpages to unlimited"
	rubysource=/opt/axsh/wakame-vdc/dcmgr/lib/dcmgr/drivers/hypervisor/linux_hypervisor/linux_container/openvz.rb
	"$DATADIR/vmdir-1box/ssh-to-kvm.sh" sudo grep 'privvmpage.*unlimited' "$rubysource" 1>/dev/null 2>&1
	$skip_step_if_already_done
	(
	    cat <<EOF
	    rubysource='$rubysource'
EOF
	    cat <<'EOF'
            sudo cp "$rubysource" /tmp/ # for debugging
	    orgcode="$(sudo cat "$rubysource")"
            # original line: sh("vzctl set %s --privvmpage %s --save",[hc.inst_id, (inst[:memory_size] * 256)])
	    replaceme='vzctl set %s --privvmpage'
	    while IFS= read -r ln; do
		  if [[ "$ln" == *${replaceme}* ]]; then
                     echo "## $ln"
                     echo '        sh("vzctl set %s --privvmpage unlimited --save",[hc.inst_id])'
                     cat # copy the rest unchanged
                     break
		  fi
		  echo "$ln"
	    done <<<"$orgcode" | sudo bash -c "cat >'$rubysource'"
EOF
	) | "$DATADIR/vmdir-1box/ssh-to-kvm.sh"
    ) ; prev_cmd_failed
    
    (
	$starting_step "Hack Wakame-vdc to always set each openvz VM's DISKSPACE to 10G:15G"
	rubysource=/opt/axsh/wakame-vdc/dcmgr/templates/openvz/template.conf
	"$DATADIR/vmdir-1box/ssh-to-kvm.sh" sudo grep 'DISKSPACE.*10G' "$rubysource" 1>/dev/null 2>&1
	$skip_step_if_already_done
	(
	    cat <<EOF
	    rubysource='$rubysource'
EOF
	    cat <<'EOF'
            sudo cp "$rubysource" /tmp/ # for debugging
	    orgcode="$(sudo cat "$rubysource")"
            # original line: DISKSPACE="2G:2.2G"
	    replaceme='DISKSPACE'
	    while IFS= read -r ln; do
		  if [[ "$ln" == *${replaceme}* ]]; then
                     echo "## $ln"
                     echo 'DISKSPACE="10G:15G"'
                     cat # copy the rest unchanged
                     break
		  fi
		  echo "$ln"
	    done <<<"$orgcode" | sudo bash -c "cat >'$rubysource'"
EOF
	) | "$DATADIR/vmdir-1box/ssh-to-kvm.sh"
    ) ; prev_cmd_failed
    
    (
	$starting_group "Install customized machine image into OpenVZ 1box image"
	imagefile="centos-6.6.x86_64.openvz.md.raw.tar.gz"
	imageid="bo-centos1d64"
	! [ -f "$DATADIR/$imagefile" ]
	$skip_group_if_unnecessary

	(
	    $starting_step "Compute backup object parameters for customized image"
	    [ -f "$DATADIR/$imagefile.params" ]

	    $skip_step_if_already_done; set -e
	    "$DATADIR/vmapp-vdc-1box/gen-image-size-params.sh" \
		"$DATADIR/$imagefile" >"$DATADIR/$imagefile.params"
	) ; prev_cmd_failed

	(
	    $starting_step "Install customized image"

	    [ -x "$DATADIR/vmdir-1box/ssh-to-kvm.sh" ] &&
		"$DATADIR/vmdir-1box/ssh-to-kvm.sh" '[ -d /var/lib/wakame-vdc/images/hide ]' 2>/dev/null
	    $skip_step_if_already_done; set -e

	    ( cd "$DATADIR" &&
		    tar c "$imagefile" | "$DATADIR/vmdir-1box/ssh-to-kvm.sh" tar xv
	    )
	    "$DATADIR/vmdir-1box/ssh-to-kvm.sh" <<EOF
set -x
sudo mkdir -p /var/lib/wakame-vdc/images/hide
sudo mv /var/lib/wakame-vdc/images/$imagefile /var/lib/wakame-vdc/images/hide
sudo mv /home/centos/$imagefile /var/lib/wakame-vdc/images

/opt/axsh/wakame-vdc/dcmgr/bin/vdc-manage backupobject modify \
   $imageid $(cat "$DATADIR/$imagefile.params")

EOF
	) ; prev_cmd_failed
    ) ; prev_cmd_failed

) ; prev_cmd_failed
