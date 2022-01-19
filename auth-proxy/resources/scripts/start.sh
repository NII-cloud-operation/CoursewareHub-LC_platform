#!/bin/bash
set -e

j2 /etc/templates/nginx.conf.j2 -o /etc/nginx/nginx.conf
j2 /etc/templates/module_cron.php.j2 -o /var/www/simplesamlphp/config/module_cron.php
j2 /etc/templates/cron_root.j2 -o /var/spool/cron/crontabs/root

chmod 600 /var/spool/cron/crontabs/root

if [ -n "${AUTH_FQDN}" ] ; then
    touch /var/www/simplesamlphp/modules/metarefresh/enable
    j2 /etc/templates/config-metarefresh.php.j2 -o /var/www/simplesamlphp/config/config-metarefresh.php
    j2 /etc/templates/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
else
    rm -f /var/www/simplesamlphp/modules/metarefresh/enable
fi

/usr/bin/supervisord -n -c /etc/supervisord.conf
