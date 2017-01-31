#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed
export CODEDIR="$(cd "$(dirname "$0")" && pwd -P)" || reportfailed

if [ "$DATADIR" = "" ]; then
    # Choose directory of symbolic link by default
    DATADIR="$CODEDIR"
fi
source "$DATADIR/simple-defaults-for-bashsteps.source"
source "$DATADIR/datadir.conf"

(
    $starting_step "Expand VM image for ${DATADIR##*/}"
    # the next line conveniently fails if $IMAGEFILENAME is null, but points
    # to something awkward that needs some thought (TODO)
    [ -f "$DATADIR/$IMAGEFILENAME" ]
    $skip_step_if_already_done ; set -e

    echo -n "Expanding image file..."
    tar xzvf "$imagesource" -C "$DATADIR" >"$DATADIR"/tar.stdout || reportfailed "untaring of image"
    echo ".done."
    read IMAGEFILENAME rest <"$DATADIR"/tar.stdout
    [ "$rest" = "" ] || reportfailed "unexpected output from tar: $(<"$DATADIR"/tar.stdout)"
    echo 'IMAGEFILENAME="'$IMAGEFILENAME'"' >>"$DATADIR/datadir.conf"
    [ -f "${imagesource%.tar.gz}.sshuser" ] && cp "${imagesource%.tar.gz}.sshuser" "$DATADIR/sshuser"
    [ -f "${imagesource%.tar.gz}.sshkey" ] && {
	cp "${imagesource%.tar.gz}.sshkey" "$DATADIR/sshkey"
	chmod 600 "$DATADIR/sshkey" ; }
)
