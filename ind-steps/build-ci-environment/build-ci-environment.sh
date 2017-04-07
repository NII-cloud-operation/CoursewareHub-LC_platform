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
    $starting_group "Install jupyter in main KVM"
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
	$starting_group "Configure jupyter server"

	# Refs:
	#    https://jupyter.readthedocs.io/en/latest/projects/config.html
	#    http://jupyter-notebook.readthedocs.io/en/latest/public_server.html
	JCFG="/home/ubuntu/.jupyter/jupyter_notebook_config.py"

	(
	    $starting_step "Generate default configuration file"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
[ -f "$JCFG" ]									
EOF
	    $skip_step_if_already_done; set -e
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
jupyter notebook --generate-config
EOF
	) ; $iferr_exit
	
	(
	    $starting_step "Set jupyter password"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
grep -q sha1 "$JCFG"
EOF
	    $skip_step_if_already_done; set -e
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
# set default password
saltpass="\$(echo $'from notebook.auth import passwd\nprint(passwd("${JUPYTER_PASSWORD:=stepbystep}"))' | python)"
echo "c.NotebookApp.password = '\$saltpass'" >>"$JCFG"
EOF
	) ; $iferr_exit
	
	(
	    $starting_step "Miscellaneous jupyter configuration"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
grep -qF -e "c.NotebookApp.ip = '*'" "$JCFG"
EOF
	    $skip_step_if_already_done; set -e
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
echo "c.NotebookApp.ip = '*'" >>"$JCFG"
EOF
	) ; $iferr_exit
	
	(
	    $starting_step "Set up jupyter with supervisord"
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" 2>/dev/null 1>/dev/null <<EOF
[ -f /etc/supervisor/conf.d/jupyter.conf ]
EOF
	    $skip_step_if_already_done; set -e
	    # ref: https://github.com/jupyterhub/jupyterhub/issues/317
	    [ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
		"$DATADIR/$VMDIR/ssh-shortcut.sh" sudo bash 2>/dev/null 1>/dev/null <<EOF
cat >/etc/supervisor/conf.d/jupyter.conf <<EOF2
[program:jupyter]
user=ubuntu
command=/home/ubuntu/.pyenv/versions/anaconda3-4.3.0/bin/jupyter notebook
directory=/home/ubuntu
autostart=true
autorestart=true
startretries=1
exitcodes=0,2
stopsignal=TERM
redirect_stderr=true
stdout_logfile=/var/log/jupyter.log
stdout_logfile_maxbytes=1MB
stdout_logfile_backups=10
stdout_capture_maxbytes=1MB
EOF2

/usr/bin/supervisorctl reload

EOF
	) ; $iferr_exit
    ) ; $iferr_exit
    
    (
	$starting_group "Install extra kernels and extensions for jupyter"
	
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

) ; $iferr_exit

(
    $starting_group "Set up for CI notebook"
    (
	$starting_step "Set ssh key pair"
	[ -x "$DATADIR/$VMDIR/ssh-shortcut.sh" ] &&
	    "$DATADIR/$VMDIR/ssh-shortcut.sh" <<EOF 2>/dev/null 1>/dev/null
[ -f .ssh/id_rsa ]
EOF
	$skip_step_if_already_done; set -e

	# following instructions on https://github.com/takluyver/bash_kernel
	"$DATADIR/$VMDIR/ssh-shortcut.sh" <<'EOF'
ssh-keygen -t rsa -N "" -f /home/ubuntu/.ssh/id_rsa
EOF
	
    ) ; $iferr_exit

) ; $iferr_exit
