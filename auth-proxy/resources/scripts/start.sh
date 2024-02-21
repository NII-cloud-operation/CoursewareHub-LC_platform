#!/bin/bash
set -e

TEMPLATE_DIR=/etc/templates

j2 ${TEMPLATE_DIR}/embedded-wayf-config.js.j2 -o /var/www/simplesamlphp/templates/includes/embedded-wayf-config.js
j2 ${TEMPLATE_DIR}/embedded-wayf-loader.js.j2 -o /var/www/simplesamlphp/templates/includes/embedded-wayf-loader.js
j2 ${TEMPLATE_DIR}/nginx.conf.j2 -o /etc/nginx/nginx.conf
j2 ${TEMPLATE_DIR}/config.php.j2 -o /var/www/simplesamlphp/config/config.php
j2 ${TEMPLATE_DIR}/module_cron.php.j2 -o /var/www/simplesamlphp/config/module_cron.php
j2 ${TEMPLATE_DIR}/cron_root.j2 -o /var/spool/cron/crontabs/root

chmod 600 /var/spool/cron/crontabs/root

if [[ -n "${AUTH_FQDN}" ]] ; then
    # Join federation via IdP Proxy
    j2 ${TEMPLATE_DIR}/module_metarefresh.php.j2 -o /var/www/simplesamlphp/config/module_metarefresh.php
    j2 ${TEMPLATE_DIR}/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
elif [[ "$ENABLE_FEDERATION" == "1" || "$ENABLE_FEDERATION" == "yes" ]]; then
    # Join federation directly
    if [[ "$ENABLE_TEST_FEDERATION" == "1" || "$ENABLE_TEST_FEDERATION" == "yes" ]]; then
        j2 ${TEMPLATE_DIR}/federation/module_metarefresh-test.php.j2 -o /var/www/simplesamlphp/config/module_metarefresh.php
    else
        j2 ${TEMPLATE_DIR}/federation/module_metarefresh.php.j2 -o /var/www/simplesamlphp/config/module_metarefresh.php
    fi
    j2 ${TEMPLATE_DIR}/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
fi

/usr/bin/supervisord -n -c /etc/supervisord.conf
