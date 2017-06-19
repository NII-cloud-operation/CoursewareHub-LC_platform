#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

usage()
{
    cat 1>&2 <<EOF
The first parameter should be a path to a kvm-steps vmdir.
This script probably must be copied to the same machine that
holds the vmdir and run from there.
EOF
    exit 255
}

vmdir="$(cd "$1"; pwd -P)"

[ -f "$vmdir/kvm-boot.sh" ] && [ -f "$vmdir/datadir.conf" ] || usage

set -e

cd "$vmdir"

vmname="${vmdir##*/}"

rm -fr "$vmdir"/"$vmname"

ptar="$vmname-proxy.tar.gz"

[ -f "$ptar" ] && reportfailed "$ptar already exists"

[ -d "$vmname" ] && reportfailed "The directory $vmname already exists"

getipaddress()
{
    read -a line1array <<<"$(ip route get 8.8.8.8)"
    # something like: ( 8.8.8.8 via 157.1.207.254 dev bond0  src 157.1.207.248 )
    echo "${line1array[@]: -1}" # last token, the space is necessary
}

mkdir "$vmname"
cd "$vmname"

iphere="$(getipaddress)"

cat >proxy-shell.sh <<EOF
#!/bin/bash
reportfailed()
{
    echo "Script failed...exiting. (\$*)" 1>&2
    exit 255
}
[ "\$*" == "" ] || reportfailed "Don't use parameters: pipe script through stdin"
ssh $USER@$iphere 'cd "$vmdir" ; bash'
EOF

# declare up here and use declare below to avoid
# so many escaped dollar signs in the code
initialize_hooks_for_remote_proxy()
{
    for v in ${export_variables_for_remote:=} ; do
	fname="$(eval echo \$$v)"
	echo export "$v='$fname'"
	declare -f "$fname" 2>/dev/null && echo export -f "$fname"
    done
    for fname in ${export_funtions_for_remote:=} ; do
	declare -f "$fname" 2>/dev/null && echo export -f "$fname"
    done
}

for s in kvm-boot.sh kvm-kill.sh kvm-shutdown-via-ssh.sh kvm-expand-fresh-image.sh; do
    cat >"$s" <<EOF
#!/bin/bash

$(declare -f initialize_hooks_for_remote_proxy)

ssh $USER@$iphere -q <<EOF2
\$(initialize_hooks_for_remote_proxy)
'$vmdir/$s' \$@
EOF2
EOF
done

for s in ssh-shortcut.sh ; do  # turn on tty for interactive use
    cat >"$s" <<EOF
#!/bin/bash
ssh $USER@$iphere -qt '"$vmdir/$s"' "\$@"
EOF
done

chmod +x *.sh

cp ../datadir.conf .

cd ..

tar czvf "$ptar" "$vmname"
