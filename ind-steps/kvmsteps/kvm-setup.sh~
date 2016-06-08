#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

[ "$1" != "" ] && fullpath="$(readlink -f $1)"

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

if [ "$DATADIR" = "" ]; then
    # Choose current directory by default
    DATADIR="$(pwd)"
fi
source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

# avoids errors on first run, but maybe not good to change state
# outside of a step
touch "$DATADIR/datadir.conf" 2>/dev/null

source "$DATADIR/datadir.conf" 2>/dev/null
: ${imagesource:=$fullpath}

(
    $starting_step "Sanity checks before setting up VM dir"
    false # always do these
    $skip_step_if_already_done ; set -e

    # ...what sanity checking would be good?
    [ -f "$DATADIR/kvm-boot.sh" ] && reportfailed "Apparently already set up in $DATADIR"
    [ -d "$DATADIR" ] || reportfailed "No directory found at DATADIR=$DATADIR"

    # Assumption just to get things going...
    [[ "$imagesource" == *.tar.gz ]] || reportfailed "Expecting .tar.gz file."
) ; prev_cmd_failed

(
    $starting_step "Copy initial VM image"
    # the next line conveniently fails if $IMAGEFILENAME is null, but points
    # to something awkward that needs some thought (TODO)
    [ -f "$DATADIR/$IMAGEFILENAME" ]
    $skip_step_if_already_done ; set -e

    tar xzvf "$imagesource" -C "$DATADIR" >"$DATADIR"/tar.stdout || reportfailed "untaring of image"
    read IMAGEFILENAME rest <"$DATADIR"/tar.stdout
    [ "$rest" = "" ] || reportfailed "unexpected output from tar: $(<"$DATADIR"/tar.stdout)"
    echo 'IMAGEFILENAME="'$IMAGEFILENAME'"' >>"$DATADIR/datadir.conf"
set -x
    [ -f "${imagesource%.tar.gz}.sshuser" ] && cp "${imagesource%.tar.gz}.sshuser" "$DATADIR/sshuser"
    [ -f "${imagesource%.tar.gz}.sshkey" ] && {
	cp "${imagesource%.tar.gz}.sshkey" "$DATADIR/sshkey"
	chmod 600 "$DATADIR/sshkey" ; }
    exit 0
) ; prev_cmd_failed
source "$DATADIR/datadir.conf" 2>/dev/null

(
    $starting_step "Copy control scripts to VM directory"
    [ -f "$DATADIR/kvm-boot.sh" ]
    $skip_step_if_already_done ; set -e
    #ln -s "$ORGCODEDIR/vmdir-scripts"/* "$DATADIR"
    # Stopped using links so that the VM dir can be copied
    # to different machines
    cp -a "$ORGCODEDIR/vmdir-scripts"/* "$DATADIR"
    # These script dependencies need to be copied too:
    cp -a "$ORGCODEDIR/simple-defaults-for-bashsteps.source" "$DATADIR"
    cp -a "$ORGCODEDIR/monitor-process.sh" "$DATADIR"
)
