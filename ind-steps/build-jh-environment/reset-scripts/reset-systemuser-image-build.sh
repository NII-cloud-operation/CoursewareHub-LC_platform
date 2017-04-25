#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# It seems that when the source above sources datadir.conf, this line
# is not done correctly:
#    "declare -a 'vmlist=([0]="jhvmdir-hub" [1]="jhvmdir" [2]="jhvmdir-node1" [3]="jhvmdir-node2")'"
# such that set -u makes "${vmlist[@]}" flag an error.  So
# loading it again directly from this file:
source "$DATADIR/datadir.conf"

# TODO: figure out the above bash bug/oddity

"$LINKCODEDIR/reset-systemuser-image-distribution.sh" wrapped

remove_layer()
{
    layerid="$1"
    (
	$starting_step "Delete $layerid docker image on jhvmidr"
	"$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF 1>/dev/null 2>&1
out="\$(docker images)"
[[ "\$out" == *$layerid* ]] && exit 1
exit 0
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF
docker rmi "$layerid"
EOF
    ) ; $iferr_exit
}

remove_repo()
{
    repoid="$1"
    (
	$starting_step "Delete $repoid source git repository on jhvmidr"
	"$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF 1>/dev/null 2>&1
[ -d /srv/$repoid ]  && exit 1
exit 0
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF
set -e
rm -fr /srv/$repoid
EOF
    ) ; $iferr_exit
}

layerlist_upper="
  triggers/systemuser
  jupyter/systemuser
"

layerlist_lower="
  jupyterhub/singleuser
  jupyter/scipy-notebook
  jupyter/minimal-notebook
  jupyter/base-notebook
"
repolist_upper="
  dockerspawner
  systemuser
"
repolist_lower="
  docker-stacks
"

for layer in $layerlist_upper ; do
    (
	$starting_group "Remove images for $layer"
	remove_layer "$layer"
    ) ; $iferr_exit
done

: ${DOALL:=''}

for layer in $layerlist_lower ; do
    (
	$starting_group "Remove images for $layer (skipped unless environment variable DOALL is not null)"
	[ "$DOALL" = "" ]
	$skip_group_if_unnecessary
	remove_layer "$layer"
    ) ; $iferr_exit
done

for repo in $repolist_upper ; do
    (
	$starting_group "Remove repository for $repo"
	remove_repo "$repo"
    ) ; $iferr_exit
done

for repo in $repolist_lower ; do
    (
	$starting_group "Remove repository for $repo (skipped unless environment variable DOALL is not null)"
	[ "$DOALL" = "" ]
	$skip_group_if_unnecessary
	remove_repo "$repo"
    ) ; $iferr_exit
done

(
    $starting_step "Delete systemuser snapshot on jhvmidr"
    "$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF 1>/dev/null 2>&1
[ -f systemuser.tar ] && exit 1
exit 0
EOF
    $skip_step_if_already_done; set -e
    "$DATADIR"/jhvmdir/ssh-shortcut.sh sudo bash <<EOF
set -e
rm -fr systemuser.tar
EOF
) ; $iferr_exit
