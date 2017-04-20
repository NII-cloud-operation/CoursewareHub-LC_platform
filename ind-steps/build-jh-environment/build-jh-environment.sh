#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

VMDIR=jhvmdir


(
    $starting_group "Cache used repositories locally"

    clone_remote_git()
    {
	giturl="$1"
	reponame="${2:-}" # simple workaround for name conflicts, can be empty
	
	[ "$reponame" = "" ] && reponame="$(basename "$giturl" .git)" # basename removes the .git suffix

	# NOTE: This puts the repository cache mixed with the original
	# scripts instead of the build directory, so that it can be shared
	# between multiple builds.
	(
	    $starting_step "Cache git repository: $giturl"
	    [ -d "$ORGCODEDIR/repo-cache/$reponame" ]
	    $skip_step_if_already_done; set -e
	    mkdir -p "$ORGCODEDIR/repo-cache"
	    cd "$ORGCODEDIR/repo-cache"
	    git clone "$giturl" "$reponame"
	) ; $iferr_exit
    }


    clone_remote_git https://github.com/triggers/jupyterhub-deploy.git
    clone_remote_git https://github.com/triggers/systemuser.git
    clone_remote_git https://github.com/minrk/restuser.git

    # next is for 3 docker files: scipy-notebook/Dockerfile, minimal-notebook/Dockerfile, and base-notebook/Dockerfile
    clone_remote_git https://github.com/jupyter/docker-stacks

    # next is for two docker files: singleuser/Dockerfile and systemuser/Dockerfile
    clone_remote_git https://github.com/jupyterhub/dockerspawner

    clone_remote_git https://github.com/jupyterhub/jupyterhub jh-jupyterhub
    clone_remote_git https://github.com/triggers/jupyterhub.git
) ; $iferr_exit

( # not a step, just a little sanity checking
    if [ -d "$ORGCODEDIR/repo-cache/jupyterhub-deploy" ]; then
	cd "$ORGCODEDIR/repo-cache/jupyterhub-deploy"
	git log | grep 07bc0aa6aaad5df 1>/dev/null && exit 0
	cat 1>&2 <<EOF
The repository jupyterhub-deploy does not have commit 07bc0aa6aaad5df,
which means it is probably too old of a version to work with the
recent changes to this build script.
EOF
	exit 1
    fi
) ; $iferr_exit

(
    $starting_group "Copy repositories to build VMs"

    copy_in_one_cached_repository()
    {
	local repo_name="$1"
	local vmdir="$2"
	local targetdir="$3"
	local sudo="$4"
	(
	    $starting_step "Copy $repo_name repository into $vmdir"
	    [ -x "$DATADIR/$vmdir/ssh-shortcut.sh" ] &&
		"$DATADIR/$vmdir/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d "$targetdir/$repo_name" ]
EOF
	    $skip_step_if_already_done ; set -e
	    (
		# clone from our cached copy
		cd "$ORGCODEDIR/repo-cache"
		tar c "$repo_name"
	    ) | "$DATADIR/$vmdir/ssh-shortcut.sh" $sudo tar x -C "$targetdir"
	) ; $iferr_exit

	# now run the step below to set the commit
	commitvarname="setcommit_${repo_name//-/_}" # e.g.: setcommit_jh_jupyterhub
	commitid="$(eval echo \$$commitvarname)"
	checkout_commitid "$repo_name" "$vmdir" "$targetdir" "$sudo" "$commitid"
    }

    checkout_commitid()
    {
	local repo_name="$1"
	local vmdir="$2"
	local targetdir="$3"
	local sudo="$4"
	local commitid="$5"
	(
	    $starting_step "Checkout commit ${commitid:0:9} for $repo_name"
	    [ "$commitid" = "unchanged" ] || {
		[ -x "$DATADIR/$vmdir/ssh-shortcut.sh" ] &&
		    "$DATADIR/$vmdir/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
set -ex
cd "$targetdir/$repo_name"
now_at="\$($sudo git rev-parse HEAD)" 
[[ "$commitid" == \${now_at:0:7}* ]]  # commit_id must be at least 7 characters long
EOF
	    }
	    $skip_step_if_already_done ; set -e
	    [ -x "$DATADIR/$vmdir/ssh-shortcut.sh" ] &&
		"$DATADIR/$vmdir/ssh-shortcut.sh" <<EOF # 2>/dev/null 1>/dev/null
set -ex
cd "$targetdir/$repo_name"
$sudo git reset --hard
$sudo git checkout "$commitid"
EOF
	) ; $iferr_exit
    }

    copy_in_one_cached_repository jupyterhub-deploy "$VMDIR"     /home/ubuntu ""
    copy_in_one_cached_repository jupyterhub        "$VMDIR-hub" /srv  sudo  # TODO: is this dup still needed here
    copy_in_one_cached_repository systemuser        "$VMDIR"     /srv  sudo

    copy_in_one_cached_repository docker-stacks     "$VMDIR"     /srv  sudo
    copy_in_one_cached_repository dockerspawner     "$VMDIR"     /srv  sudo

    copy_in_one_cached_repository jh-jupyterhub     "$VMDIR"     /srv  sudo
#    checkout_commitid jh-jupyterhub     "$VMDIR"     /srv  sudo "$setcommit_jh_jupyterhub"
    
    copy_in_one_cached_repository jupyterhub        "$VMDIR"     /srv  sudo

    # This repository is not for a docker container.  It is for a process started
    # directly on the hub VM.
    copy_in_one_cached_repository restuser          "$VMDIR-hub" /srv  sudo

    (
	$starting_step "Copy auth-proxy repository into $VMDIR-hub"
	# Building this docker directly on the hub VM for now.
	[ -x "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d "/srv/auth-proxy" ]
EOF
	$skip_step_if_already_done ; set -e
	(
	    # clone from our cached copy
	    cd "$ORGCODEDIR/../.."
	    tar c auth-proxy
	) | "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" sudo tar x -C /srv
    ) ; $iferr_exit

) ; $iferr_exit

(
    $starting_step "Install Docker in main KVM"
    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] && {
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<<"which docker" 2>/dev/null 1>&2
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/$VMDIR/ssh-shortcut.sh" "curl -fsSL https://get.docker.com/ | sudo sh"
    "$DATADIR/$VMDIR/ssh-shortcut.sh" "sudo usermod -aG docker ubuntu"
    # #	touch "$DATADIR/extrareboot" # necessary to make the usermod take effect in Jupyter environment
) ; $iferr_exit

# # Maybe the reboot was never necessary?  Simply doing ssh again is enough?
# #    : ${extrareboot:=} # set -u workaround
# #    if [ "$extrareboot" != "" ] || \
    # #	   [ -f "$DATADIR/extrareboot" ] ; then  # this flag can also be set before calling ./build-nii.sh
# #	rm -f "$DATADIR/extrareboot"
# #	## TODO: this step is dynamically added/removed, which is awkward for bashsteps.  Alternatives?
# #	"$DATADIR/$VMDIR/kvm-shutdown-via-ssh.sh" wrapped ; $iferr_exit
# #    fi
# #    if [ -f "$DATADIR/$VMDIR/kvm-boot.sh" ]; then  # TODO: find better way
# #	"$DATADIR/$VMDIR/kvm-boot.sh" wrapped ; $iferr_exit
# #    fi

(
    $starting_group "Build docker images cache for later distribution"

    (
	$starting_group "Build systemuser image from scratch"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f systemuser.tar ]
EOF
	$skip_group_if_unnecessary
	# Note that if cached image have been copied to the ansible VM from
	# elsewhere, the actual image may not exist on ansible VM, which
	# is OK because it is not used to create containers in the ansible VM.

	(
	    $starting_step "Build base-notebook docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep jupyter/base-notebook
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/docker-stacks/base-notebook

docker build -t jupyter/base-notebook .
EOF
	) ; $iferr_exit

	(
	    $starting_step "Build minimal-notebook docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep jupyter/minimal-notebook
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/docker-stacks/minimal-notebook

docker build -t jupyter/minimal-notebook .
EOF
	) ; $iferr_exit

	(
	    $starting_step "Build scipy-notebook docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep jupyter/scipy-notebook
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/docker-stacks/scipy-notebook

docker build -t jupyter/scipy-notebook .
EOF
	) ; $iferr_exit

	(
	    $starting_step "Build singleuser docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep jupyterhub/singleuser
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/dockerspawner/singleuser
docker build -t jupyterhub/singleuser .
EOF
	) ; $iferr_exit

	(
	    $starting_step "Build jupyter/systemuser docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep jupyter/systemuser
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/dockerspawner/systemuser
docker build -t jupyter/systemuser .
EOF
	) ; $iferr_exit

	(
	    $starting_step "Build triggers/systemuser docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep triggers/systemuser
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/systemuser

docker build -t triggers/systemuser .
EOF
	) ; $iferr_exit
	
    ) ; $iferr_exit

    (
	$starting_group "Build jupyterhub image from scratch"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f jupyterhub.tar ]
EOF
	$skip_group_if_unnecessary
	# Note that if cached image have been copied to the ansible VM from
	# elsewhere, the actual image may not exist on ansible VM, which
	# is OK because it is not used to create containers in the ansible VM.

	(
	    $starting_step "Build jupyterhub/jupyterhub docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep jupyter/jupyterhub
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/jh-jupyterhub

# Note we are pulling from the newer jupyterhub/jupyterhub, but still
# calling it jupyter/jupyterhub to match name in triggers/systemuser.
docker build -t jupyter/jupyterhub .
EOF
	) ; $iferr_exit

	(
	    $starting_step "Build triggers/jupyterhub docker image"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
docker images | grep triggers/jupyterhub
EOF
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
cd /srv/jupyterhub

docker build -t triggers/jupyterhub .
EOF
	) ; $iferr_exit

    ) ; $iferr_exit

    (
	$starting_step "Cache systemuser docker image to tar file"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f systemuser.tar ]
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
docker save triggers/systemuser >systemuser.tar
EOF
    ) ; $iferr_exit

    (
	$starting_step "Cache jupyterhub docker image to tar file"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f jupyterhub.tar ]
EOF
	$skip_step_if_already_done ; set -e

	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
docker save triggers/jupyterhub >jupyterhub.tar
EOF
    ) ; $iferr_exit


) ; $iferr_exit

(
    $starting_group "Make TLS/SSL certificates with docker"

    # following the guide at: https://github.com/compmodels/jupyterhub-deploy/blob/master/INSTALL.md
    KEYMASTER="docker run --rm -v /home/ubuntu/jupyterhub-deploy/certificates/:/certificates/ cloudpipe/keymaster"

    (
	$starting_step "Gather random data from host, set vault-password"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f jupyterhub-deploy/certificates/password ]
EOF
	$skip_step_if_already_done ; set -e

	# The access to /dev/random must be done on the host because
	# it hangs in KVM
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
mkdir -p jupyterhub-deploy/certificates

echo ubuntu >/home/ubuntu/jupyterhub-deploy/vault-password

cat >jupyterhub-deploy/certificates/password <<EOF2
$(cat /dev/random | head -c 128 | base64)
EOF2

${KEYMASTER} ca

EOF
    ) ; $iferr_exit

    do-one-keypair()
    {
	(
	    $starting_step "Generate a keypair for a server $1"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f /home/ubuntu/jupyterhub-deploy/certificates/$1-key.pem ]
EOF
	    $skip_step_if_already_done ; set -e
	    
	    # The access to /dev/random must be done on the host because
	    # it hangs in KVM
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
set -x
cd jupyterhub-deploy/certificates
${KEYMASTER} signed-keypair -n $1 -h $1.website.com -p both -s IP:$2
EOF
	) ; $iferr_exit
    }
    hubip="$(source "$DATADIR/$VMDIR-hub/datadir.conf" ; echo "$VMIP")"
    do-one-keypair hub "$hubip"
    for n in $node_list; do
        nodeip="$(source "$DATADIR/$VMDIR-$n/datadir.conf" ; echo "$VMIP")"
	do-one-keypair "$n" "$nodeip"
    done
) ; $iferr_exit

(
    $starting_group "Pre-ansible build steps"
    (
	$starting_step "Adjust ansible config files for node_list"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null
[ -f nodelist ] && [ "\$(cat nodelist)" = "$node_list" ]
EOF
	$skip_step_if_already_done ; set -e

	invfile="$(
  echo "[jupyterhub_host]"
  hubip="$(source "$DATADIR/$VMDIR-hub/datadir.conf" ; echo "$VMIP")"
  printf "hub ansible_ssh_user=root ansible_ssh_host=%s servicenet_ip=%s\n" "$hubip" "$hubip"
  echo
  echo "[jupyterhub_nodes]"
  for n in $node_list; do
     nodeip="$(source "$DATADIR/$VMDIR-$n/datadir.conf" ; echo "$VMIP")"
     printf "%s ansible_ssh_user=root ansible_ssh_host=%s fqdn=%s servicenet_ip=%s\n" "$n" "$nodeip" "$n" "$nodeip"
  done
  echo
  echo "[jupyterhub_nfs]"
  echo "hub"
  echo ""
  echo "[proxy]"
  echo "hub"
  echo ""
  echo "[nfs_clients]"
  for n in $node_list; do
     echo "$n"
  done
)"
	
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
# TODO: improve this temporary fix...maybe putting in ansible vault or using 
#       hub's servicenet_ip.
tmppath=/home/ubuntu/jupyterhub-deploy/roles/proxy/defaults/main.yml
sed -i 's,192.168.11.88,$(source "$DATADIR/$VMDIR-hub/datadir.conf" ; echo "$VMIP"),' \$tmppath

node_list="$node_list"

[ -f jupyterhub-deploy/inventory.bak ] || cp jupyterhub-deploy/inventory jupyterhub-deploy/inventory.bak 

# write out a complete inventory file constructed on deploy VM
cat >jupyterhub-deploy/inventory <<EOFinv
$invfile
EOFinv

[ -f jupyterhub-deploy/script/assemble_certs.bak ] || cp jupyterhub-deploy/script/assemble_certs jupyterhub-deploy/script/assemble_certs.bak

while IFS='' read -r ln ; do
   case "\$ln" in
     name_map\ =*)
         echo "\$ln"
         echo -n '    "hub": "hub"'
         for n in \$node_list; do
            echo ','
            printf '    "%s": "%s"' "\$n" "\$n"
         done
         while IFS='' read -r ln ; do
             [[ "\$ln" == }* ]] && break
         done
         echo
         echo "\$ln"
         ;;
     *) echo "\$ln"
        ;;
   esac
done <jupyterhub-deploy/script/assemble_certs.bak  >jupyterhub-deploy/script/assemble_certs

# Debugging output:
echo ------ jupyterhub-deploy/inventory ------------
diff jupyterhub-deploy/inventory.bak jupyterhub-deploy/inventory || :
echo ------ jupyterhub-deploy/script/assemble_certs ---------
diff  jupyterhub-deploy/script/assemble_certs.bak jupyterhub-deploy/script/assemble_certs || :

# Flag that step has been done:
echo "$node_list" >nodelist
EOF
    ) ; $iferr_exit

    (
	exit 0  # The contents here are now part of triggers/jupyterhub-deploy.git
	$starting_step "Set secrets.vault"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f /home/ubuntu/jupyterhub-deploy/secrets.vault.yml.org ]
EOF
	$skip_step_if_already_done ; set -e
	
	# The access to /dev/random must be done on the host because
	# it hangs in KVM
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
set -x
cd jupyterhub-deploy/
cp secrets.vault.yml secrets.vault.yml.org

# not sure yet how to set this:
cp secrets.vault.yml.example secrets.vault.yml

sed -i "s,.*other_ssh_keys.*,other_ssh_keys: [ '\$(< "/home/ubuntu/.ssh/authorized_keys")' ]," secrets.vault.yml

sed -i "s,.*configproxy_auth_token.*,configproxy_auth_token: '2fd34c8b5dc9ba64754e754114f37a7b33eff14b7f415e4f761d28a6b516a3be'," secrets.vault.yml

sed -i "s,.*jupyterhub_admin_user.*,jupyterhub_admin_user: 'ubuntu'," secrets.vault.yml

sed -i "s,.*cookie_secret.*,cookie_secret: 'cookie_secret'," secrets.vault.yml

cp secrets.vault.yml secrets.vault.yml.tmp-for-debugging

ansible-vault encrypt --vault-password-file vault-password secrets.vault.yml
EOF
    ) ; $iferr_exit

    (
	$starting_step "Set users.vault"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f /home/ubuntu/jupyterhub-deploy/users.vault.yml.org ]
EOF
	$skip_step_if_already_done ; set -e
	
	# The access to /dev/random must be done on the host because
	# it hangs in KVM
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -e
set -x
cd jupyterhub-deploy/
cp users.vault.yml users.vault.yml.org
cat >users.vault.yml <<EOF2
jupyterhub_admins:
- potter
EOF2
ansible-vault encrypt --vault-password-file vault-password users.vault.yml
EOF
    ) ; $iferr_exit

    (
	$starting_step "Copy private ssh key to main KVM, plus minimal ssh config"
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null
[ -f .ssh/id_rsa ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -x

cat >.ssh/id_rsa <<EOF2
$(< "$DATADIR/$VMDIR/sshkey")
EOF2
chmod 600 .ssh/id_rsa

cat >.ssh/config <<EOF2
Host *
        StrictHostKeyChecking no
        TCPKeepAlive yes
        UserKnownHostsFile /dev/null
	ForwardAgent yes
EOF2
chmod 644 .ssh/config

EOF
    ) ; $iferr_exit

    (
	$starting_step "Run ./script/assemble_certs (from the jupyterhub-deploy repository)"
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null
cd jupyterhub-deploy
[ -f ./host_vars/node2 ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -x
set -e

cd jupyterhub-deploy
./script/assemble_certs 

EOF
    ) ; $iferr_exit

    (
	$starting_step "Copy user ubuntu's .ssh dir to shared NFS area"
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null 1>&2
[ -d /mnt/nfs/home/ubuntu/.ssh ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF
set -x
set -e

sudo mkdir -p /mnt/nfs/home/ubuntu
sudo chown ubuntu:ubuntu /mnt/nfs/home/ubuntu
sudo tar c /home/ubuntu/.ssh | ( cd /mnt/nfs && sudo tar xv )

EOF
    ) ; $iferr_exit
) ; $iferr_exit

(
    $starting_step "Run main **Ansible script** (PART 1)"
    nodesarray=( $node_list )
    vmcount=$(( ${#nodesarray[@]} + 1 )) # nodes + just the hub
    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null
set -x
cd jupyterhub-deploy
# last part of ansible log should show "failed=0" three times. e.g:
#   PLAY RECAP *********************************************************************
#   hub                        : ok=97   changed=84   unreachable=0    failed=0   
#   node1                      : ok=41   changed=32   unreachable=0    failed=0   
#   node2                      : ok=41   changed=32   unreachable=0    failed=0   
count="\$(tail deploylog-part1.log | grep -o "unreachable=0.*failed=0" | wc -l)"
[ "\$count" -eq "$vmcount" ]
EOF
    $skip_step_if_already_done
    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -x
set -e

cd jupyterhub-deploy
time ./script/deploy "-part1" | tee -a deploylog-part1.log

EOF
) ; $iferr_exit

(
    $starting_step "Build auth-proxy docker image"
    [ -x "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" ] &&
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
sudo docker images | grep auth-proxy
EOF
    $skip_step_if_already_done ; set -e

    "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" sudo bash <<'EOF'
set -e
cd /srv/auth-proxy
echo "$PATH"
whereis docker
docker build -t auth-proxy:latest .
EOF
    
) ; $iferr_exit

(
    $starting_group "Distribute cached docker images"

    distribute_one_image()
    {
	imagename="$1"
	tarname="$2"
	targetvm="$3"
	(
	    $starting_step "Distribute $1 docker image to $targetvm"
	    [ -x "$DATADIR/$targetvm/ssh-shortcut.sh" ] &&
		"$DATADIR/$targetvm/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
sudo docker images | grep $imagename
EOF
	    $skip_step_if_already_done ; set -e

	    echo "   Starting transfer at: $(date)"
	    hubip="$(source "$DATADIR/$targetvm/datadir.conf" ; echo "$VMIP")"
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -ex
cat $tarname | ssh root@$hubip docker load
EOF
	    echo "   Finished transfer at: $(date)"
	) ; $iferr_exit
    }
    distribute_one_image triggers/jupyterhub jupyterhub.tar "$VMDIR-hub"
    distribute_one_image triggers/systemuser systemuser.tar "$VMDIR-hub"
    for n in $node_list; do
	distribute_one_image triggers/systemuser systemuser.tar "$VMDIR-$n"
    done
) ; $iferr_exit

(
    $starting_step "Put in workaround to avoid a docker-compose problem"
    [ -x "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" ] &&
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f /srv/jh-image-wrap/Dockerfile ]
EOF
    $skip_step_if_already_done ; set -e
	    "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" sudo bash <<EOF
set -e
mkdir -p /srv/jh-image-wrap
cat >/srv/jh-image-wrap/Dockerfile <<EOF2
FROM triggers/jupyterhub

# This empty Dockerfile's purpose is to work around a problem with docker-compose.
# The triggers/jupyterhub image should already exist before docker-compose is called,
# but docker-compose tries to verify that there is no more-recent image at docker.io.
# This image is not at docker.io, so an error is returned.  But if we just build on
# top of the image with this docker file, then all is OK.

EOF2

EOF

) ; $iferr_exit

(
    $starting_step "Run main **Ansible script** (PART 2)"  # mostly copy/pasted from above
    nodesarray=( $node_list )
    vmcount=$(( ${#nodesarray[@]} + 1 )) # nodes + just the hub
    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null
set -x
cd jupyterhub-deploy
count="\$(tail deploylog-part2.log | grep -o "unreachable=0.*failed=0" | wc -l)"
[ "\$count" -eq "$vmcount" ]
EOF
    ansibleOK="$?"
    [ "$ansibleOK" = "0" ] &&
	[ -x "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" ] &&
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
# has docker run been done by docker compose?
# i.e. container exists, even if stopped
sudo docker ps -a | grep root_jupyterhub_1
EOF
    nothingReset="$?"
    
    [ "$ansibleOK" = "0" ] && [ "$nothingReset" = "0" ]
    $skip_step_if_already_done
    
    # docker-compose refuses to run if it finds a container it does not like.
    # docker-compose does not like the root_nginx_3 container because it is
    # "without label". So if this Ansible is being run because of a reset/rebuild
    # operation, the current workaround is that root_nginx_3 must be removed first.
    # root_nginx_3 will be recreated in a later step.  TODO: find a better way to deal with this.
    "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" sudo docker rm -f root_nginx_3 -q || :
    
    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF
set -x
set -e

cd jupyterhub-deploy
time ./script/deploy "-part2" | tee -a deploylog-part2.log

EOF
) ; $iferr_exit


(
    $starting_group "Post-ansible build steps"

    (
	$starting_step "Copy proxy's certificate and key to hub VM"
	# TODO: find out why Ansible step did not do this correctly.
	# When using Ansible to do this, all the end of line characters
	# were stripped out.
	# Note: the root_nginx_1 container probably needs restarting,
	#       which seems to happen automatically eventually.
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
lines=\$(cat /tmp/proxykey /tmp/proxycert | wc -l)
[ "\$lines" -gt 10 ]
EOF
	$skip_step_if_already_done
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF
set -x
set -e

# For now, just reusing the self-signed cert used for the hub.

sudo tee /tmp/proxycert <<EOF2
$("$DATADIR/$VMDIR/ssh-shortcut.sh" cat jupyterhub-deploy/certificates/hub-cert.pem)
EOF2

sudo tee /tmp/proxykey <<EOF3
$("$DATADIR/$VMDIR/ssh-shortcut.sh" cat jupyterhub-deploy/certificates/hub-key.pem)
EOF3

EOF
    ) ; $iferr_exit

    (
	$starting_step "Copy manage-tools to hub VM"
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" -q <<EOF 2>/dev/null >/dev/null
[ -f /jupyter/admin/admin_tools/00_GuidanceForTeacher.ipynb ]
EOF
	$skip_step_if_already_done; set -e
	cd "$ORGCODEDIR/../.."
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" rm -fr /tmp/manage-tools
	tar cz manage-tools | \
	    "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" tar xzv -C /tmp
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" -q <<EOF
    set -e
    # mkdir stuff is also in multihubctl, but needed here
    # because multihubctl has not been run yet.
    sudo mkdir -p /jupyter/admin/{admin_tools,tools}
    sudo chmod a+wr /jupyter/admin/{admin_tools,tools}

    sudo cp /tmp/manage-tools/admin-tools/* /jupyter/admin/admin_tools
    sudo cp /tmp/manage-tools/tools/* /jupyter/admin/tools

    sudo cp /tmp/manage-tools/common/* /jupyter/admin/admin_tools
    sudo cp /tmp/manage-tools/common/* /jupyter/admin/tools

    cd /jupyter/admin
    sudo chmod 444  */*ipynb
    sudo chmod 555 tools/notebook-diff admin_tools/notebook-diff admin_tools/collect-answer
EOF
    ) ; $iferr_exit

    (
	$starting_step "Copy in adapt-notebooks-for-user.sh and background-command-processor.sh"
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
[ -f /srv/adapt-notebooks-for-user.sh ] && [ -f /srv/background-command-processor.sh ]
EOF
	$skip_step_if_already_done; set -e
	cd "$ORGCODEDIR/../.."
	tar c adapt-notebooks-for-user.sh background-command-processor.sh | "$DATADIR/$VMDIR-hub/ssh-shortcut.sh" sudo tar xv -C /srv
    ) ; $iferr_exit

    (
	$starting_step "Start background-command-processor.sh in background on 192.168.11.88 (hub) VM"
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF 2>/dev/null >/dev/null
ps auxwww | grep 'background-command-processo[r]' 1>/dev/null 2>&1
EOF
	$skip_step_if_already_done; set -e
	"$DATADIR/$VMDIR-hub/ssh-shortcut.sh" <<EOF
set -x
cd /srv
sudo bash -c 'setsid ./background-command-processor.sh 1>>bcp.log 2>&1 </dev/null &'
EOF
    ) ; $iferr_exit
) ; $iferr_exit

source "$ORGCODEDIR/post-build-for-auth-proxy.dstep"

touch "$DATADIR/flag-inital-build-completed"
