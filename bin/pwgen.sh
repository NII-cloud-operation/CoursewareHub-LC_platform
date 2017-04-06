#!/bin/bash

exclude="[1I0O\"\'\(\)\^~\\\`\{\}_\?<>]"
while :
do
  password=$(mkpasswd -l 10)
  if [[ "$password" =~ $exclude ]]; then
      continue
  fi
  break
done

echo $password
