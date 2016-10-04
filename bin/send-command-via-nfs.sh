#!/bin/bash


send_command_via_nfs()
{
    fn=~/.commands/test
    {
	echo "$*"
	echo "EOCommand"
    } >$fn-queued

    lastoutput=""
    while [[ "$lastoutput" != *EOResult* ]]; do
	sleep 1

	# keep reopening the file because tail on NFS delays quite a bit
	contents="$(< "$fn-queued")"

	alloutput="${contents#*EOCommand?}"
	if [ "$alloutput" != "$lastoutput" ]; then
	    newtext="${alloutput#"$lastoutput"}"
	    lastoutput="$alloutput"

	    echo -n "${newtext/EOResult/}"
	fi
    done
    mv "$fn-queued" "$fn-done"
}


if [ "$1" != just-source ]; then
    send_command_via_nfs "$@"
fi
