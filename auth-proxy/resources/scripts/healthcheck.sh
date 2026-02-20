#!/bin/bash

set -xe

if [[ -e /.acme-init ]]; then
    exit 0
fi

curl -k -f https://localhost/php/login.php
