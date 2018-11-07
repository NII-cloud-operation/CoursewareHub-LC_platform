#!/bin/bash
set -e

/update_idp_proxy_metadata.sh
/config.py
/usr/bin/supervisord -n -c /etc/supervisord.conf
