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
	mkdir "/home/$studentid/role_model"
	cp -al "/home/$teacherid"/*  "/home/$studentid/role_model"
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

if [ "$(whoami)" != root ]; then
    echo "Must be root" 1>&2
    exit 1
fi

while true; do
    scan-for-commands
    sleep 1
done
