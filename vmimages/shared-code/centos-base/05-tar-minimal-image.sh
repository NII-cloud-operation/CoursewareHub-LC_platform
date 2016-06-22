#!/bin/bash

[ -d "$CODEDIR" ] && [ -n "$DATADIR" ] || {
    echo "($0)" 1>&2
    echo "This step expects calling script to set up environment" 1>&2
    exit 255
}

$starting_step "Tar minimal image"
[ -f "$DATADIR/minimal-image.raw.tar.gz" ]
$skip_step_if_already_done; set -e
cd "$DATADIR/"
time tar czSvf minimal-image.raw.tar.gz minimal-image.raw
