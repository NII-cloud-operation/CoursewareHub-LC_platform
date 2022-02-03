#!/bin/bash
set -e

TEMPLATE_DIR=/etc/templates

j2 ${TEMPLATE_DIR}/nginx.conf.j2 -o /etc/nginx/nginx.conf
j2 ${TEMPLATE_DIR}/config.php.j2 -o /var/www/simplesamlphp/config/config.php
j2 ${TEMPLATE_DIR}/module_cron.php.j2 -o /var/www/simplesamlphp/config/module_cron.php
j2 ${TEMPLATE_DIR}/cron_root.j2 -o /var/spool/cron/crontabs/root

chmod 600 /var/spool/cron/crontabs/root

if [[ -n "${AUTH_FQDN}" ]] ; then
    # Join federation via IdP Proxy
    touch /var/www/simplesamlphp/modules/metarefresh/enable
    j2 ${TEMPLATE_DIR}/config-metarefresh.php.j2 -o /var/www/simplesamlphp/config/config-metarefresh.php
    j2 ${TEMPLATE_DIR}/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
elif [[ "$ENABLE_FEDERATION" == "1" || "$ENABLE_FEDERATION" == "yes" ]]; then
    # Join federation directly
    touch /var/www/simplesamlphp/modules/metarefresh/enable
    if [[ "$ENABLE_TEST_FEDERATION" == "1" || "$ENABLE_TEST_FEDERATION" == "yes" ]]; then
        j2 ${TEMPLATE_DIR}/federation/config-metarefresh-test.php.j2 -o /var/www/simplesamlphp/config/config-metarefresh-test.php
    else
        j2 ${TEMPLATE_DIR}/federation/config-metarefresh.php.j2 -o /var/www/simplesamlphp/config/config-metarefresh.php
    fi
    j2 ${TEMPLATE_DIR}/federation/selectidp-dropdown.php.j2 -o /var/www/simplesamlphp/templates/selectidp-dropdown.php
    j2 ${TEMPLATE_DIR}/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
else
    # without federation
    rm -f /var/www/simplesamlphp/modules/metarefresh/enable
fi

/usr/bin/supervisord -n -c /etc/supervisord.conf
