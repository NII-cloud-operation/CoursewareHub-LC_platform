#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# It seems that when the source above sources datadir.conf, this line
# is not done correctly:
#    "declare -a 'vmlist=([0]="jhvmdir-hub" [1]="jhvmdir" [2]="jhvmdir-node1" [3]="jhvmdir-node2")'"
# such that set -u makes "${vmlist[@]}" flag an error.  So
# loading it again directly from this file:
source "$DATADIR/datadir.conf"

# TODO: figure out the above bash bug/oddity

"$LINKCODEDIR/reset-jupyterhub-image-distribution.sh" wrapped

(
    $starting_step "Delete JupyterHub snapshot and source git repository"
    "$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF 1>/dev/null 2>&1
[ -f jupyterhub.tar ] && exit 1
[ -d /srv/jh-jupyterhub ]  && exit 1
[ -d /srv/jupyterhub ]  && exit 1
exit 0
EOF
    $skip_step_if_already_done; set -e
    "$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF
rm -fr jupyterhub.tar
rm -fr /srv/jh-jupyterhub
rm -fr /srv/jupyterhub
EOF
) ; $iferr_exit
