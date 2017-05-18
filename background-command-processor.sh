#!/bin/bash

# Executes commands in file placed by some other process on shared
# NFS.  The result is placed in the same file.  The format of the file is:

# {command text}
# EOCommand
# {command result text}
# EOResult

# Information is only appended to the file.  Polling is done on the
# EOCommand and EOResult tags to wait for complete info.

initialize-teacher-notebooks()
{
    teacherid="$1"
    shift
    
    if ! [ -d "/home/$teacherid" ]; then
	echo "No teacher with id=$studentid"
	return
    fi

    studentid="$*"
    if [ "$studentid" != "$teacherid" ]; then
	echo "Required first parameter should be the teacher id (i.e. $teacherid)"
	return
    fi

    echo "Deleting existing notebooks of $studentid."
    rm "/home/$studentid"/* -fr  # TODO: rethink this

    echo "Initializing notebooks for $studentid."
    /srv/adapt-notebooks-for-user.sh "$studentid"
    echo "Done."
}

clear-notebooks()
{
    teacherid="$1"
    shift
    
    if ! [ -d "/home/$teacherid" ]; then
	echo "No teacher with id=$studentid"
	return
    fi

    for studentid in "$@"; do
	if ! [ -d "/home/$studentid" ]; then
	    echo "No student with id=$studentid"
	    continue
	fi
	echo "Deleting existing notebooks of $studentid."
	rm "/home/$studentid"/* -fr  # TODO: rethink this
	echo "Done."
    done
}

distribute-notebooks()
{
    teacherid="$1"
    shift
    
    if ! [ -d "/home/$teacherid" ]; then
	echo "No teacher with id=$teacherid"
	return
    fi

    for studentid in "$@"; do
	if ! [ -d "/home/$studentid" ]; then
	    echo "No student with id=$studentid"
	    continue
	fi
	echo "Deleting existing notebooks of $studentid."
	rm "/home/$studentid"/* -fr  # TODO: rethink this

	# Copy teacher notebooks to student container via NFS:
	echo "Copying notebooks..."
	cp -a "/home/$teacherid"/*  "/home/$studentid/"
	chown -R "$studentid:$studentid" "/home/$studentid/"
	# Also make read-only copy:
	echo "Creating role_model directory..."
	rm -fr "/home/$studentid/role_model"
	ln -sf "/home/.others/$teacherid"  "/home/$studentid/role_model"
	echo "Done."
    done
}

process-one-command()
{
    set -x
    justcmd="${cmdtext/EOCommand/}"
    case "$justcmd" in
	fortesting*)
	    bash <<<"${justcmd/fortesting/}" >>"$cmdfile"
	    ;;
	distribute-notebooks*)
	    read stripcmd teacherid sids <<<"$justcmd"
	    distribute-notebooks $teacherid $sids >>"$cmdfile"
	    ;;
	clear-notebooks*)
	    read stripcmd teacherid sids <<<"$justcmd"
	    clear-notebooks $teacherid $sids >>"$cmdfile"
	    ;;
	initialize-teacher-notebooks*)
	    read stripcmd teacherid sids <<<"$justcmd"
	    initialize-teacher-notebooks $teacherid $sids >>"$cmdfile"
	    ;;
    esac
    echo EOResult >>"$cmdfile"
    set +x
}

scan-for-commands()
{
    shopt -s nullglob
    for cmdfile in /home/*/.commands/*-queued; do
	cmdtext="$(< "$cmdfile")"
	[[ "$cmdtext" == *EOCommand* ]] || continue  # skip if client has not finished writing
	[[ "$cmdtext" == *EOResult* ]] && continue  # skip if already processed
	process-one-command
    done
}

students-home-dir-hack()
{
    # This is probably temporary and will be moved/rewritten when the design
    # stabilizes.

    # Make sure user directories have the symbolic links
    shopt -s nullglob
    for udir in /mnt/nfs/home/*; do
	userid="${udir##*/}"
	# skip known administrators and the teacher
	[ "$userid" = "potter" ] && continue
	[ "$userid" = "ubuntu" ] && continue
	[ -f "/jupyter/admin/$userid" ] && continue
	for link in textbook tools info; do
	    if ! [ -h "$udir/$link" ]; then
		ln -s "/jupyter/admin/$link" "$udir/$link" 2>/dev/null
		chown -h "$userid:$userid" "$udir/$link" 2>/dev/null
	    fi
	done
	for dir in private_info; do
	    if ! [ -d "$udir/$dir" ]; then
		mkdir -p "$udir/$dir" 2>/dev/null
		chown -h "$userid:$userid" "$udir/$dir" 2>/dev/null
	    fi
	done

	ipycfg="$udir/.ipython/profile_default/ipython_config.py"
	[ -f "$ipycfg" ] || {
	    mkdir -p "${ipycfg%/*}"
	    echo "c.InteractiveShellApp.matplotlib = 'inline'" >>"$ipycfg"
	    chown -R "$userid:$userid" "$udir/.ipython"
	}
	
	# Hopefully this next one will be very temporary:
	# Make user dirs world writable so teacher can copy in notebooks with
	# simple unix commands.  Do this every time so teacher can also
	# copy out new files that the student might put in.
	# TODO: avoid this, using groups, perhaps.
	(
	    # Put in exception to skip ssh related things that should not be world readable/writable
	    # and also skip symbol links.
	    if cd "$udir"; then
		shopt -s nullglob
		shopt -s dotglob
		for p in * ; do
		    [ -L "$p" ] && continue
		    [ "$p" = .ssh ] && continue
		    [[ "$p" = *key* ]] && continue
		    chmod -R a+wr "$p"
		done
	    fi
	)
	# the directory itself needs to be writable or else the jupyter server container does not launch
	# Note: no "-R" here
	chmod a+wr "$udir"
    done
}

if [ "$(whoami)" != root ]; then
    echo "Must be root" 1>&2
    exit 1
fi

while true; do
    scan-for-commands
    students-home-dir-hack
    sleep 5
done
