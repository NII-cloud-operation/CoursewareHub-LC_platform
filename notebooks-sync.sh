#!/bin/bash

direction="$1" # tovm or fromvm
dirname="$2" # notebooks or bin

: "${dirname:=notebooks}"

set -e
cd "$(dirname $(readlink -f "$0"))"

case "$1" in
    tovm)
	rsync -avz -e ./vmdir/ssh-to-kvm.sh ./"$dirname"/ :/home/centos/"$dirname"
	;;
    fromvm)
	rsync -avz -e ./vmdir/ssh-to-kvm.sh :/home/centos/"$dirname"/ ./"$dirname"
	;;
    *) echo "First parameter should be tovm or fromvm"
       ;;
esac
