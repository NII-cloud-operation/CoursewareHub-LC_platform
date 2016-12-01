#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

snapshot_source="$(readlink -f "$1")" || reportfailed

new_dir="$2"

[ "$new_dir" != "" ] || reportfailed "second parameter the dirpath where to create the new JupyterHub environment"

[ -d "$new_dir" ] && reportfailed "$new_dir already exists"

DATADIRCONF="$snapshot_source/datadir-jh.conf"
source "$DATADIRCONF"

[ "$node_list" != "" ] || reportfailed "node_list not defined"

vmlist=(
    jhvmdir-hub
    jhvmdir
    $(
	for i in $node_list; do
	    echo jhvmdir-$i
	done
    )
)

for i in "${vmlist[@]}"; do
    [ -f "$snapshot_source/$i-snapshot.tar" ] || [ -f "$snapshot_source/$i-snapshot.tar.gz" ] || \
	reportfailed "$snapshot_source/$i-snapshot.tar{.gz} not found"
done

mkdir "$new_dir" || reportfailed mkdir "$new_dir"

cp "$DATADIRCONF" "$new_dir/datadir-jh.conf"

cat >>"$new_dir/datadir-jh.conf" <<EOF
$(declare -p vmlist )

snapshot_source="$snapshot_source"
EOF

ln -s "$snapshot_source" "$new_dir/snapshot_source_link"

ln -s "$(readlink -f "$ORGCODEDIR/restore-environment-from-snapshot.sh")" "$new_dir/"

echo Success
