#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# It seems that when the source above sources datadir.conf, this line
# is not done correctly:
#    "declare -a 'vmlist=([0]="jhvmdir-hub" [1]="jhvmdir" [2]="jhvmdir-node1" [3]="jhvmdir-node2")'"
# such that set -u makes "${vmlist[@]}" flag an error.  So
# loading it again directly from this file:
source "$DATADIR/datadir.conf"

# TODO: figure out the above bash bug/oddity

(
    $starting_step "Stop JupyterHub container and remove image"
    "$DATADIR"/jhvmdir-hub/ssh-shortcut.sh sudo bash <<EOF 1>/dev/null 2>&1
sudo docker images | grep root_jupyterhub && exit 1
sudo docker images | grep triggers/jupyterhub && exit 1
exit 0 # neither image is there
EOF
    $skip_step_if_already_done; set -e
    "$DATADIR"/jhvmdir-hub/ssh-shortcut.sh sudo bash <<EOF
  echo "Stopping container root_jupyterhub_1 and removing its image"
  docker rm -f root_jupyterhub_1
  docker rmi root_jupyterhub
  docker rmi triggers/jupyterhub
EOF
) ; $iferr_exit
