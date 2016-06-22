#!/bin/bash

reportfailed()
{
    echo "Script failed...exiting. ($*)" 1>&2
    exit 255
}

export ORGCODEDIR="$(cd "$(dirname $(readlink -f "$0"))" && pwd -P)" || reportfailed

if [ "$DATADIR" = "" ]; then
    # Default to putting output in the code directory, which means
    # a separate clone of the repository for each build
    DATADIR="$ORGCODEDIR"
fi
source "$ORGCODEDIR/simple-defaults-for-bashsteps.source"

# avoids errors on first run, but maybe not good to change state
# outside of a step
touch "$DATADIR/datadir.conf"

source "$DATADIR/datadir.conf"

imagesource="$DATADIR/vmimages/centos-7.1.1511-x86_64-base/output/minimal-image.raw.tar.gz"

(
    $starting_group "Build minimal Centos 7 image"
    [ -f "$imagesource" ]
    $skip_group_if_unnecessary ; set -e
    "$DATADIR/vmimages/centos-7.1.1511-x86_64-base/build.sh"
) ; prev_cmd_failed

(
    $starting_step "Setup user/sshkey for use by ind-steps/kvmsteps"
    [ -f "${imagesource%.tar.gz}.sshuser" ]
    $skip_step_if_already_done; set -e
    cp "${imagesource%/*}/tmp-sshkeypair" "${imagesource%.tar.gz}.sshkey"
    echo "root" >"${imagesource%.tar.gz}.sshuser"

) ; prev_cmd_failed

(
    $starting_group "Set up install Jupyter in VM"
    (
	$starting_group "Set up vmdir"
	[ -x "$DATADIR/vmdir/kvm-boot.sh" ]
	$skip_group_if_unnecessary
	(
	    $starting_step "Make vmdir"
	    [ -d "$DATADIR/vmdir" ]
	    $skip_step_if_already_done ; set -e
	    mkdir "$DATADIR/vmdir"
	    # increase default mem to give room for a wakame instance or two
	    echo ': ${KVMMEM:=4096}' >>"$DATADIR/vmdir/datadir.conf"
	) ; prev_cmd_failed

	DATADIR="$DATADIR/vmdir" \
	       "$ORGCODEDIR/ind-steps/kvmsteps/kvm-setup.sh" \
	       "$DATADIR/vmimages/centos-7.1.1511-x86_64-base/output/minimal-image.raw.tar.gz"
    ) ; prev_cmd_failed

    (
	$starting_group "Install Jupyter in the Centos 7 image"
	[ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ]
	$skip_group_if_unnecessary

	# TODO: this guard is awkward.
	[ -x "$DATADIR/vmdir/kvm-boot.sh" ] && \
	    "$DATADIR/vmdir/kvm-boot.sh"


	(
	    $starting_step "Create centos user account"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		"$DATADIR/vmdir/ssh-to-kvm.sh" [ -d /home/centos ] 2>/dev/null
	    }
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" <<EOF
adduser centos
echo 'centos ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers
EOF
	)

	for p in wget bzip2 rsync; do
	    (
		$starting_step "Install $p"
		[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		    [ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ] || \
			[[ "$("$DATADIR/vmdir/ssh-to-kvm.sh" which $p 2>/dev/null)" = *$p* ]]
		}
		$skip_step_if_already_done ; set -e

		"$DATADIR/vmdir/ssh-to-kvm.sh" <<EOF
yum install -y $p
EOF
	    )
	done
	
	(
	    $starting_step "Do short set of script lines to install jupyter"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		[ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ] || \
		    [ "$("$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<"which jupyter" 2>/dev/null)" = "/home/centos/anaconda3/bin/jupyter" ]
	    }
	    $skip_step_if_already_done ; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<'EOF'
if ! [ -f Anaconda3-2.4.1-Linux-x86_64.sh ]; then
  wget  --progress=dot:mega \
     https://3230d63b5fc54e62148e-c95ac804525aac4b6dba79b00b39d1d3.ssl.cf1.rackcdn.com/Anaconda3-2.4.1-Linux-x86_64.sh
fi

chmod +x Anaconda3-2.4.1-Linux-x86_64.sh

./Anaconda3-2.4.1-Linux-x86_64.sh -b

echo 'export PATH="/home/centos/anaconda3/bin:$PATH"' >>.bashrc

export PATH="/home/centos/anaconda3/bin:$PATH"

conda install -y jupyter
EOF
	) ; prev_cmd_failed

	(
	    $starting_step "Install bash_kernel"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		## TODO: the next -f test is probably covered by the group
		[ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ] || \
		    "$DATADIR/vmdir/ssh-to-kvm.sh" '[ -d /home/centos/anaconda3/lib/python3.5/site-packages/bash_kernel ]' 2>/dev/null
	    }
	    $skip_step_if_already_done; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<'EOF'
pip install bash_kernel
python -m bash_kernel.install
EOF
	) ; prev_cmd_failed

	# Nbextensions used to be installed after tarring the basic
	# jupyter install image.  Now it is here mainly because
	# the nbextensions page is not showing up without restarting
	# the server.  The VM reboot that comes after this place
	# in ./build-nii.sh solves this.  Another reason is that
	# installing nbextensions takes a little time, so it is nice
	# to put it into the snapshot.  A third reason is that updates
	# to extensions can break our system, so that makes it very nice
	# to have working versions locked away in the snapshot.
	(
	    $starting_step "Install nbextensions to VM"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<'pip list | grep nbextensions' 2>/dev/null 1>/dev/null
	    }
	    $skip_step_if_already_done; set -e

	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<'EOF'

pip install https://github.com/ipython-contrib/IPython-notebook-extensions/archive/master.zip --user

EOF
	) ; prev_cmd_failed

	## Dynamically generate the steps for these:
	enable_these="
  usability/collapsible_headings/main
  usability/init_cell/main
  usability/runtools/main
  usability/toc2/main
"

	# Note, it seems that collapsible_heading has replaced hierarchical_collapse,
	# Therefore from the above I just removed this:  testing/hierarchical_collapse/main

	cfg_path="./.jupyter/nbconfig/notebook.json"
	for ext in $enable_these; do
	    (
		$starting_step "Enable extension: $ext"
		[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<"grep $ext $cfg_path" 2>/dev/null 1>&2
		}
		$skip_step_if_already_done; set -e

		"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<"jupyter nbextension enable $ext"
	    ) ; prev_cmd_failed
	done

	(
	    $starting_step "Set default password for jupyter, plus other easy initial setup"
	    JCFG="/home/centos/.jupyter/jupyter_notebook_config.py"
	    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
		[ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ] || \
		    "$DATADIR/vmdir/ssh-to-kvm.sh" grep sha1 "$JCFG" 2>/dev/null 1>&2
	    }
	    $skip_step_if_already_done ; set -e

	    # http://jupyter-notebook.readthedocs.org/en/latest/public_server.html
	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF
set -x
[ -f "$JCFG" ] || jupyter notebook --generate-config

# set default password
saltpass="\$(echo $'from notebook.auth import passwd\nprint(passwd("${JUPYTER_PASSWORD:=warmwinter}"))' | python)"
echo "c.NotebookApp.password = '\$saltpass'" >>"$JCFG"
echo "c.NotebookApp.ip = '*'" >>"$JCFG"

# move jupyter's default directory away from \$HOME
mkdir notebooks
echo "c.NotebookApp.notebook_dir = 'notebooks'" >>"$JCFG"
EOF
	    "$DATADIR/vmdir/ssh-to-kvm.sh" <<EOF
# autostart on boot
echo "(setsid su - centos -c '/home/centos/anaconda3/bin/jupyter notebook' > /var/log/jupyter.log 2>&1) &" | \
   bash -c "cat >>/etc/rc.local"
# TODO: stop using rc.local, but until then, this is supposed to work:
chmod +x /etc/rc.d/rc.local
EOF
	) ; prev_cmd_failed

	# TODO: this guard is awkward.
	[ -x "$DATADIR/vmdir/kvm-shutdown-via-ssh.sh" ] && \
	    "$DATADIR/vmdir/kvm-shutdown-via-ssh.sh"
	true # needed so the group does not throw an error because of the awkwardness in the previous command
    ) ; prev_cmd_failed

    (
	$starting_step "Make snapshot of image with jupyter installed"
	[ -f "$DATADIR/vmdir/minimal-image-w-jupyter.raw.tar.gz" ]
	$skip_step_if_already_done ; set -e
	cd "$DATADIR/vmdir/"
	tar czSvf minimal-image-w-jupyter.raw.tar.gz minimal-image.raw
    ) ; prev_cmd_failed
) ; prev_cmd_failed

(
    $starting_step "Expand fresh image from snapshot of image with Jupyter installed"
    [ -f "$DATADIR/vmdir/minimal-image.raw" ]
    $skip_step_if_already_done ; set -e
    cd "$DATADIR/vmdir/"
    tar xzSvf minimal-image-w-jupyter.raw.tar.gz
) ; prev_cmd_failed

# TODO: this guard is awkward.
[ -x "$DATADIR/vmdir/kvm-boot.sh" ] && \
    "$DATADIR/vmdir/kvm-boot.sh"

(
    $starting_step "Install Docker"
    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<"which docker" 2>/dev/null 1>&2
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/vmdir/ssh-to-kvm.sh" "curl -fsSL https://get.docker.com/ | sh"
    "$DATADIR/vmdir/ssh-to-kvm.sh" "usermod -aG docker centos"
    "$DATADIR/vmdir/ssh-to-kvm.sh" "service docker start"
    touch "$DATADIR/extrareboot" # necessary to make the usermod take effect in Jupyter environment
) ; prev_cmd_failed

if [ "$extrareboot" != "" ] || \
       [ -f "$DATADIR/extrareboot" ] ; then  # this flag can also be set before calling ./build-nii.sh
    rm -f "$DATADIR/extrareboot"
    [ -x "$DATADIR/vmdir/kvm-shutdown-via-ssh.sh" ] && \
	"$DATADIR/vmdir/kvm-shutdown-via-ssh.sh"
fi

if [ -x "$DATADIR/vmdir/kvm-boot.sh" ]; then
    "$DATADIR/vmdir/kvm-boot.sh"
fi

(  # TODO, redo this the systemd way
    $starting_step "Make sure Docker is started"
    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	out="$("$DATADIR/vmdir/ssh-to-kvm.sh" "service docker status" 2>/dev/null)"
	[[ "$out" == *running* ]]
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/vmdir/ssh-to-kvm.sh" "service docker start"
) ; prev_cmd_failed

(
    $starting_group "Try to load cached Jupyter docker image"
    ! [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
    $skip_group_if_unnecessary

    (
	$starting_step "Load cached jupyter/minimal-notebook image"
	"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
	$skip_step_if_already_done
	# Note: in next line stdin is used for data, not a script to bash
	cat "$DATADIR/jupyter-in-docker-cached.tar.gz" | gunzip - | \
	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c "'docker load'" centos
    )
)


(
    $starting_step "Do docker pull jupyter/minimal-notebook"
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep jupyter/minimal-notebook >/dev/null
EOF
    $skip_step_if_already_done
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF
docker pull jupyter/minimal-notebook
EOF
)

(
    $starting_step "Save cached Jupyter docker image"
    [ -f "$DATADIR/jupyter-in-docker-cached.tar.gz" ]
    $skip_step_if_already_done
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF | gzip - >"$DATADIR/jupyter-in-docker-cached.tar.gz"
set -x
docker save jupyter/minimal-notebook
EOF
)    

(
    $starting_step "Customize Jupyter docker image to make localbuild/customized"
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF 2>/dev/null
docker images | grep localbuild/customized >/dev/null
EOF
    $skip_step_if_already_done
    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<EOF
set -x
rm -fr dbuild
mkdir dbuild
cd dbuild

cat <<EOF2 >Dockerfile
From jupyter/minimal-notebook

RUN pip install bash_kernel && python -m bash_kernel.install
EOF2

docker build -t localbuild/customized .

EOF
)    

(
    $starting_step "Synchronize bin/ to VM"
    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<'[ "$(ls bin)" != "" ]' 2>/dev/null
    }
    $skip_step_if_already_done; set -e
    
    "$DATADIR/notebooks-sync.sh" tovm bin
) ; prev_cmd_failed

(
    $starting_group "Synchronize axsh/notebook-openvnet-gettingstarted/ to VM, if openvnetsync=true"
    [ "$openvnetsync" != "true" ]
    $skip_group_if_unnecessary

    (
	$starting_step "Clone axsh/notebook-openvnet-gettingstarted/"
	[ -d "$DATADIR/github-clones/notebook-openvnet-gettingstarted" ]
	$skip_step_if_already_done; set -e
	cd "$DATADIR"
	mkdir -p github-clones
	cd github-clones
	git clone git@github.com:axsh/notebook-openvnet-gettingstarted.git
    ) ; prev_cmd_failed

    (
	$starting_step "Synchronize cloned notebook-openvnet-gettingstarted to VM"
	[ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	    "$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<'[ "$(ls notebooks)" != "" ]' 2>/dev/null
	}
	$skip_step_if_already_done; set -e
	cd "$DATADIR"
	rsync -avz -e ./vmdir/ssh-to-kvm.sh \
	      "$DATADIR/github-clones/notebook-openvnet-gettingstarted/notebooks/" \
	      :/home/centos/notebooks
    ) ; prev_cmd_failed
) ; prev_cmd_failed

(
    ## TODO: Change the default ssh login to vmdir to use centos user, and propagate related changes
    $starting_step "Workaround for rsync as root: set all files to owner=centos"
    [ -x "$DATADIR/vmdir/ssh-to-kvm.sh" ] && {
	"$DATADIR/vmdir/ssh-to-kvm.sh" su -l -c bash centos <<<'[ "$(find ! -user centos)" == "" ]' 2>/dev/null
    }
    $skip_step_if_already_done; set -e
    "$DATADIR/vmdir/ssh-to-kvm.sh" chown -R centos:centos /home/centos
) ; prev_cmd_failed
