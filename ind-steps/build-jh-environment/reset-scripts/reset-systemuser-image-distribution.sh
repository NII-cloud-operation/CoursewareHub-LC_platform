#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

# It seems that when the source above sources datadir.conf, this line
# is not done correctly:
#    "declare -a 'vmlist=([0]="jhvmdir-hub" [1]="jhvmdir" [2]="jhvmdir-node1" [3]="jhvmdir-node2")'"
# such that set -u makes "${vmlist[@]}" flag an error.  So
# loading it again directly from this file:
source "$DATADIR/datadir.conf"

# TODO: figure out the above bash bug/oddity

do_on_node()
{
    nodedir="$1"
    (
	$starting_step "Stop systemuser container and remove image on $nodedir"
	"$DATADIR/$nodedir"/ssh-shortcut.sh sudo bash <<EOF 1>/dev/null 2>&1
sudo docker images | grep triggers/systemuser && exit 1
exit 0
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR/$nodedir"/ssh-shortcut.sh sudo bash <<'EOF'
  docker ps -a | while read containerid imageid therest ; do
     if [ "$imageid" = "triggers/systemuser" ] ; then
         echo "Removing container ${therest##* }"
         docker rm -f "$containerid"
     fi
  done

  echo "Removing image triggers/systemuser"
  docker rmi triggers/systemuser
EOF
    ) ; $iferr_exit
}

for n in  hub $node_list; do
    do_on_node jhvmdir-"$n"
done
