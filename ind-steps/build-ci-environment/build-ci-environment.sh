#!/bin/bash

source "$(dirname $(readlink -f "$0"))/bashsteps-defaults-jan2017-check-and-do.source" || exit

VMDIR=civmdir


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


    clone_remote_git https://github.com/pyenv/pyenv.git

) ; $iferr_exit

(
    $starting_group "Copy repositories to build VMs"

    copy_in_one_cached_repository()
    {
	repo_name="$1"
	vmdir="$2"
	targetdir="$3"
	sudo="$4"
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
	    ) |	"$DATADIR/$vmdir/ssh-shortcut.sh" $sudo tar x -C "$targetdir"
	) ; $iferr_exit
    }

    copy_in_one_cached_repository pyenv "$VMDIR"     /home/ubuntu ""

) ; $iferr_exit

(
    $starting_group "Set up install jupyter in main KVM"
    (
	$starting_step "Set up pyenv"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which pyenv
EOF
	$skip_step_if_already_done ; set -e
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d /home/ubuntu/pyenv ] &&
    mv -i /home/ubuntu/pyenv /home/ubuntu/.pyenv
echo 'export PYENV_ROOT="\$HOME/.pyenv"' >> ~/.profile
echo 'export PATH="\$PYENV_ROOT/bin:\$PATH"' >> ~/.profile
echo 'eval "\$(pyenv init -)"' >> ~/.profile
EOF

    ) ; $iferr_exit

    (
	$starting_step "Install anaconda"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which conda
EOF
	$skip_step_if_already_done ; set -e
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
pyenv install anaconda3-4.3.0
pyenv global anaconda3-4.3.0
EOF

    ) ; $iferr_exit

    (
	# Note: anaconda3-4.3.0 already installs jupyter so this step
	# will probably always be skipped
	$starting_step "Install jupyter"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
which jupyter
EOF
	$skip_step_if_already_done ; set -e
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
conda install -y jupyter
EOF

    ) ; $iferr_exit

    (
	$starting_step "Install bash_kernel"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -d .pyenv/versions/anaconda3-4.3.0/lib/python3.6/site-packages/bash_kernel ]
EOF
	$skip_step_if_already_done; set -e

	# following instructions on https://github.com/takluyver/bash_kernel
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<'EOF'
pip install bash_kernel
python -m bash_kernel.install
EOF
    ) ; $iferr_exit


) ; $iferr_exit

touch "$DATADIR/flag-inital-build-completed"
