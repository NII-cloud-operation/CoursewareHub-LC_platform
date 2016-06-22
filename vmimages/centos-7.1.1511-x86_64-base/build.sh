#!/bin/bash

# Because this script can be called independently,
# it must set up its bashsteps environment, e.g.
# reportfailed(), $skip_rest_if_already_done, etc.
source "$(dirname "$0")/bin/simple-defaults-for-bashsteps.source" || exit

export DATADIR="$CODEDIR/output"

source "$CODEDIR/build.conf"

# explicitly export configuration vars that will be needed in the substeps:
export CENTOSISO CENTOSMIRROR ISOMD5 MEMSIZE DISKSIZE

(
    $starting_group "Build centos-7.1.1503-x86_64-base image"

    for i in "$CODEDIR/steps-to-do"/*.sh; do
	"$i" ; prev_cmd_failed
    done
)
