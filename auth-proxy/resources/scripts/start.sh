#!/bin/bash
set -xe

TEMPLATE_DIR=/etc/templates

ACME_CONFIG_FILE=${ACME_CONFIG_FILE:-acme-config}

if [[ -e "/run/secrets/${ACME_CONFIG_FILE}" ]]; then
    source "/run/secrets/${ACME_CONFIG_FILE}"
    export ACME_SERVER \
           ACME_EAB_KID \
           ACME_EAB_HMAC_KEY \
           ACME_EAB_HMAC_ALG \
           ACME_EMAIL \
           ACME_KEY_TYPE
fi

CERT_DIR=/etc/nginx/certs
mkdir -p /etc/nginx/live-certs
if [[ -e $CERT_DIR/server.cer ]] && [[ -e $CERT_DIR/server.key ]]; then
    ln -s -f $CERT_DIR/server.cer /etc/nginx/live-certs/server.cer
    ln -s -f $CERT_DIR/server.key /etc/nginx/live-certs/server.key
else
    export ACME_ENABLED=1
    /acme-init.sh
fi

if [[ -z ${SIMPLESAMLPHP_ADMIN_PASSWORD} ]]; then
    export SIMPLESAMLPHP_ADMIN_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)
fi

jinja2 ${TEMPLATE_DIR}/embedded-wayf-config.js.j2 -o /var/www/simplesamlphp/templates/includes/embedded-wayf-config.js
jinja2 ${TEMPLATE_DIR}/embedded-wayf-loader.js.j2 -o /var/www/simplesamlphp/templates/includes/embedded-wayf-loader.js
jinja2 ${TEMPLATE_DIR}/nginx.conf.j2 -o /etc/nginx/nginx.conf
jinja2 ${TEMPLATE_DIR}/config.php.j2 -o /var/www/simplesamlphp/config/config.php
jinja2 ${TEMPLATE_DIR}/module_cron.php.j2 -o /var/www/simplesamlphp/config/module_cron.php
jinja2 ${TEMPLATE_DIR}/cron_root.j2 -o /var/spool/cron/crontabs/root

chmod 600 /var/spool/cron/crontabs/root

if [[ -n "${AUTH_FQDN}" ]] ; then
    # Join federation via IdP Proxy
    jinja2 ${TEMPLATE_DIR}/module_metarefresh.php.j2 -o /var/www/simplesamlphp/config/module_metarefresh.php
    jinja2 ${TEMPLATE_DIR}/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
elif [[ "$ENABLE_FEDERATION" == "1" || "$ENABLE_FEDERATION" == "yes" ]]; then
    # Join federation directly
    if [[ "$ENABLE_TEST_FEDERATION" == "1" || "$ENABLE_TEST_FEDERATION" == "yes" ]]; then
        jinja2 ${TEMPLATE_DIR}/federation/module_metarefresh-test.php.j2 -o /var/www/simplesamlphp/config/module_metarefresh.php
    else
        jinja2 ${TEMPLATE_DIR}/federation/module_metarefresh.php.j2 -o /var/www/simplesamlphp/config/module_metarefresh.php
    fi
    jinja2 ${TEMPLATE_DIR}/authsources.php.j2 -o /var/www/simplesamlphp/config/authsources.php
fi

exec /usr/bin/supervisord -n -c /etc/supervisord.conf
