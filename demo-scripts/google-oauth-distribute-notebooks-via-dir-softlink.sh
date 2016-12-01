#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

usage()
{
    cat <<EOF

One parameter required.  Either "initial-setup", before running the
test2-build-nbgrader-environment-w-ansible script, or "final-setup", after
the script runs successfully.

After running with final-setup, all that should be necessary is to do
port forwarding from port 443 of the machine used for the letsencrypt
certificates to the local host port that is forwarded to 192.168.11.88:433,
which can be deduced by looking at values in jhvmdir-hub/datadir.conf.

EOF
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

rootdir="${ORGCODEDIR%/*}"

[ -f "$rootdir/test2-build-nbgrader-environment-w-ansible" ] || reportfailed "bug1"

cd "$rootdir" || reportfailed

final_setup()
{
    [ -d letsencrypt ] || reportfailed
    cat ./letsencrypt/archive/opty.jp/fullchain1.pem | ./jhvmdir-hub/ssh-to-kvm.sh sudo tee /tmp/proxycert
    cat ./letsencrypt/archive/opty.jp/privkey1.pem | ./jhvmdir-hub/ssh-to-kvm.sh sudo tee /tmp/proxykey
    ./jhvmdir-hub/ssh-to-kvm.sh sudo docker stop root_nginx_1
    ./jhvmdir-hub/ssh-to-kvm.sh sudo docker start root_nginx_1
    exit 0
}


initial_setup()
{
    randomport="$(( 5000 + ( $RANDOM % 5000 ) ))"

    mkdir-conf-file()
    {
	[ -f "$4" ] && return
	cat >>"$4" <<EOF
# Not all of these are used on every VM
export EXTRAHOSTFWDREL=""

# port 22 is already assigned by kvmsteps
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::43-${2}:443
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::80-${2}:80
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::81-${2}:8001
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::83-${2}:8000
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::84-${2}:8888
EXTRAHOSTFWDREL=\$EXTRAHOSTFWDREL,hostfwd=tcp::90-${2}:9000

export mcastMAC="$3"
export mcastPORT=$randomport
EOF
	
    }

    : ${node_list:="node1 node2 node3"}
    
    # last 2 digits, MACaddr, filename
    # BTW, forgot what the twodigits column is/was used for.
    # TODO: check old commits for clues
    cinfo="
10 192.168.11.99 52:54:00:12:00:99 datadir-jh.conf
20 192.168.11.88 52:54:00:12:00:09 datadir-jh-hub.conf
$(
   for i in $node_list; do
     n="${i#node}"
     nn="$(printf "%02d" "$n")"
     echo $(( 40 + n )) 192.168.11.$n 52:54:00:12:00:$nn datadir-jh-$i.conf 
     # e.g.: 41 192.168.11.1  52:54:00:12:00:01 datadir-jh-node1.conf
   done
)
"

    while read twodigits ipaddress mac fname ; do
	[ "$fname" == "" ] && continue
	mkdir-conf-file "$twodigits" "$ipaddress" "$mac" "$fname"
    done <<<"$cinfo"

    # next line must be after mkdir-conf-file
    cat >>./datadir-jh.conf <<EOF
node_list="$node_list"
EOF

    # make sure mcast addresses are the same

    [ "$(grep -h -o mcastPORT.* *.conf | sort -u | wc -l)" -eq 1 ] || reportfailed "macPORT values differ in *.conf"


    for i in ubuntu-image-resources letsencrypt; do
	[ -d "$i" ] && continue
	if [ -d ~/"$i" ]; then
	    if ! cp -al ~/"$i" "$i"; then
		rm -fr "$i"
		cp -a ~/"$i" "$i"
	    fi
	fi
    done

    resourcelist=(
	ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshuser
	ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshkey
	ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.tar.gz
    )

    expectedresult="ceb8d811a6e225e8d1608f403dc8cbe1  ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshuser
bafa465f6f01239c2b936a126d79640f  ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.sshkey
a63168df5cad8a39aa723cfcab25c4d6  ubuntu-image-resources/ubuntu-14-instance-build.img-sshkeys-update-upgrade.tar.gz"

    echo "Checking that required resources are in place.  Should take 10 seconds or so..."
    result="$(md5sum "${resourcelist[@]}" 2>&1)"

    if [ "$result" = "$expectedresult" ]; then
	echo "OK.  Resources are in place and the md5s match."
    else
	echo Expected:
	echo "$expectedresult"
	echo
	echo "But got:"
	echo "$result"
	echo
	echo "Required resources not set up correctly."
    fi
    exit 0
}

case "$*" in
    initial-setup) initial_setup ;;
    final-setup) final_setup ;;
    *) usage ;;
esac
