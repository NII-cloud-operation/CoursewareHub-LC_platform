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

if [ "$IMAGEFILENAME" != "" ];
then
    inuse="$(lsof "$DATADIR/$IMAGEFILENAME" 2>/dev/null)"
    [ "$inuse" == "" ] || reportfailed "Existing image file in use ($IMAGEFILENAME)"
    echo "Removing previous image file."
    rm "$DATADIR/$IMAGEFILENAME" || reportfailed "Could not remove old image file"
fi

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
