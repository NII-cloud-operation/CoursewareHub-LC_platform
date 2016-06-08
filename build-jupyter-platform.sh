#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

if [ "$DATADIR" = "" ]; then
    # Default to putting output in the code directory, which means
    # a separate clone of the repository for each build
    DATADIR="$ORGCODEDIR"
fi
source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

# avoids errors on first run, but maybe not good to change state
# outside of a step
touch "$DATADIR/datadir.conf"

source "$DATADIR/datadir.conf"

(
    $starting_group "Build minimal Centos 7 image"
    [ -f "$DATADIR/vmimages/centos-7.1.1511-x86_64-base/output/minimal-image.raw.tar.gz" ]
    $skip_group_if_unnecessary ; set -e
    cd "$DATADIR/vmimages"
    ./build.sh centos-7.1.1511-x86_64-base/
) ; prev_cmd_failed

(
    $starting_group "Set up install Jupyter in VM"
    (
	$starting_group "Set up vmdir"
	[ -x "$DATADIR/vmdir/kvm-boot.sh" ]
	$skip_group_if_unnecessary
	(
	    $starting_step "Make vmdir"
	    [ -d "$DATADIR/vmdir" ]
	    $skip_step_if_already_done ; set -e
	    mkdir "$DATADIR/vmdir"
	    # increase default mem to give room for a wakame instance or two
	    echo ': ${KVMMEM:=4096}' >>"$DATADIR/vmdir/datadir.conf"
	) ; prev_cmd_failed

	DATADIR="$DATADIR/vmdir" \
	       "$ORGCODEDIR/ind-steps/kvmsteps/kvm-setup.sh" \
	       "$DATADIR/vmapp-vdc-1box/1box-openvz.netfilter.x86_64.raw.tar.gz"
    ) ; prev_cmd_failed

    (
	$starting_group "Install Jupyter in the OpenVZ 1box image"
	[ -f "$DATADIR/vmdir/1box-openvz-w-jupyter.raw.tar.gz" ]
	$skip_group_if_unnecessary

	# TODO: this guard is awkward.
	[ -x "$DATADIR/vmdir/kvm-boot.sh" ] && \
	    "$DATADIR/vmdir/kvm-boot.sh"

	(
	    $starting_step "Do short set of script lines to install jupyter"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		[ -f "$DATADIR/vmdir/1box-openvz-w-jupyter.raw.tar.gz" ] || \
		    [ "$("$DATADIR/vmdir/ssh-to-kvm.sh" which jupyter 2>/dev/null)" = "/home/centos/anaconda3/bin/jupyter" ]
	    }
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" <<'EOF'
wget  --progress=dot:mega \
   https://3230d63b5fc54e62148e-c95ac804525aac4b6dba79b00b39d1d3.ssl.cf1.rackcdn.com/Anaconda3-2.4.1-Linux-x86_64.sh

chmod +x Anaconda3-2.4.1-Linux-x86_64.sh

./Anaconda3-2.4.1-Linux-x86_64.sh -b

echo 'export PATH="/home/centos/anaconda3/bin:$PATH"' >>.bashrc

export PATH="/home/centos/anaconda3/bin:$PATH"

conda install -y jupyter
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install bash_kernel"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		## TODO: the next -f test is probably covered by the group
		[ -f "$DATADIR/vmdir/1box-openvz-w-jupyter.raw.tar.gz" ] || \
		    "$DATADIR/vmdir/ssh-to-kvm.sh" '[ -d ./anaconda3/lib/python3.5/site-packages/bash_kernel ]' 2>/dev/null
	    }
	    $skip_step_if_already_done; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" <<'EOF'
pip install bash_kernel
python -m bash_kernel.install
EOF
	) ; prev_cmd_failed

	# Nbextensions used to be installed after tarring the basic
	# jupyter install image.  Now it is here mainly because
	# the nbextensions page is not showing up without restarting
	# the server.  The VM reboot that comes after this place
	# in ./build-nii.sh solves this.  Another reason is that
	# installing nbextensions takes a little time, so it is nice
	# to put it into the snapshot.  A third reason is that updates
	# to extensions can break our system, so that makes it very nice
	# to have working versions locked away in the snapshot.
	(
	    $starting_step "Install nbextensions to VM"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		"$DATADIR/vmdir/ssh-to-kvm.sh" 'pip list | grep nbextensions' 2>/dev/null
	    }
	    $skip_step_if_already_done; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" <<'EOF'

pip install https://github.com/ipython-contrib/IPython-notebook-extensions/archive/master.zip --user

EOF
	) ; prev_cmd_failed

	## Dynamically generate the steps for these:
	enable_these="
  usability/collapsible_headings/main
  usability/init_cell/main
  usability/runtools/main
  usability/toc2/main
"

	# Note, it seems that collapsible_heading has replaced hierarchical_collapse,
	# Therefore from the above I just removed this:  testing/hierarchical_collapse/main

	cfg_path="./.jupyter/nbconfig/notebook.json"
	for ext in $enable_these; do
	    (
		$starting_step "Enable extension: $ext"
		[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		    "$DATADIR/vmdir/ssh-to-kvm.sh" "grep $ext $cfg_path" 2>/dev/null 1>&2
		}
		$skip_step_if_already_done; set -e

		"$DATADIR/vmdir/ssh-to-kvm.sh" jupyter nbextension enable $ext
	    ) ; prev_cmd_failed
	done

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
		"$DATADIR/vmdir/ssh-to-kvm.sh" mysql -u root wakame_dcmgr 2>/dev/null | \
		grep cicddemo >/dev/null
	    $skip_step_if_already_done
	    (
		declare -f do_register_keypair
		echo do_register_keypair
	    ) | "$DATADIR/vmdir/ssh-to-kvm.sh"
	    # this step was adapted from code at:
	    # https://github.com/axsh/nii-image-and-enshuu-scripts/blob/changes-for-the-2nd-class/wakame-bootstrap/wakame-vdc-install-hierarchy.sh#L426-L477
	)
	
	(
	    $starting_step "Install security group into Wakame-vdc database"
	    echo "select * from security_groups; " | \
		"$DATADIR/vmdir/ssh-to-kvm.sh" mysql -u root wakame_dcmgr 2>/dev/null | \
		grep cicddemo >/dev/null
	    $skip_step_if_already_done
	    "$DATADIR/vmdir/ssh-to-kvm.sh" \
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
	)
	
	(
	    $starting_step "Hack Wakame-vdc to always set openvz's privvmpages to unlimited"
	    rubysource=/opt/axsh/wakame-vdc/dcmgr/lib/dcmgr/drivers/hypervisor/linux_hypervisor/linux_container/openvz.rb
	    "$DATADIR/vmdir/ssh-to-kvm.sh" sudo grep 'privvmpage.*unlimited' "$rubysource" 1>/dev/null 2>&1
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
	    ) | "$DATADIR/vmdir/ssh-to-kvm.sh"
	)
	
	(
	    $starting_step "Hack Wakame-vdc to always set each openvz VM's DISKSPACE to 10G:15G"
	    rubysource=/opt/axsh/wakame-vdc/dcmgr/templates/openvz/template.conf
	    "$DATADIR/vmdir/ssh-to-kvm.sh" sudo grep 'DISKSPACE.*10G' "$rubysource" 1>/dev/null 2>&1
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
	    ) | "$DATADIR/vmdir/ssh-to-kvm.sh"
	)
	
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

		[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] &&
		    "$DATADIR/vmdir/ssh-to-kvm.sh" '[ -d /var/lib/wakame-vdc/images/hide ]' 2>/dev/null
		$skip_step_if_already_done; set -e

		( cd "$DATADIR" &&
			tar c "$imagefile" | "$DATADIR/vmdir/ssh-to-kvm.sh" tar xv
		)
		"$DATADIR/vmdir/ssh-to-kvm.sh" <<EOF
set -x
sudo mkdir -p /var/lib/wakame-vdc/images/hide
sudo mv /var/lib/wakame-vdc/images/$imagefile /var/lib/wakame-vdc/images/hide
sudo mv /home/centos/$imagefile /var/lib/wakame-vdc/images

/opt/axsh/wakame-vdc/dcmgr/bin/vdc-manage backupobject modify \
   $imageid $(cat "$DATADIR/$imagefile.params")

EOF
	    ) ; prev_cmd_failed
	)

	# TODO: this guard is awkward.
	[ -x "$DATADIR/vmdir/kvm-shutdown-via-ssh.sh" ] && \
	    "$DATADIR/vmdir/kvm-shutdown-via-ssh.sh"
	true # needed so the group does not throw an error because of the awkwardness in the previous command
    ) ; prev_cmd_failed

    (
	$starting_step "Make snapshot of image with jupyter installed"
	[ -f "$DATADIR/vmdir/1box-openvz-w-jupyter.raw.tar.gz" ]
	$skip_step_if_already_done ; set -e
	cd "$DATADIR/vmdir/"
	tar czSvf 1box-openvz-w-jupyter.raw.tar.gz 1box-openvz.netfilter.x86_64.raw
    ) ; prev_cmd_failed
) ; prev_cmd_failed
