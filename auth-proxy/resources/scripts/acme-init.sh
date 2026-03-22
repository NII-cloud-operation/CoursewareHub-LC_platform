#!/bin/bash

set -xe

CERTBOT_OPT=''
CERTBOT_SERVER_OPT=''

if [[ ! -z "${ACME_SERVER}" ]] ; then
    CERTBOT_SERVER_OPT="--server ${ACME_SERVER}"
fi

CERTBOT_OPT=''
if [[ ! -z "${ACME_EAB_KID}" ]] ; then
    CERTBOT_OPT="${CERTBOT_OPT} --eab-kid ${ACME_EAB_KID}"
fi
if [[ ! -z "${ACME_EAB_HMAC_KEY}" ]] ; then
    CERTBOT_OPT="${CERTBOT_OPT} --eab-hmac-key ${ACME_EAB_HMAC_KEY}"
fi
if [[ ! -z "${ACME_EAB_HMAC_ALG}" ]] ; then
    CERTBOT_OPT="${CERTBOT_OPT} --eab-hmac-alg ${ACME_EAB_HMAC_ALG}"
fi
if [[ ! -z "${ACME_EMAIL}" ]] ; then
    CERTBOT_OPT="${CERTBOT_OPT} -m ${ACME_EMAIL}"
fi
if [[ ! -z "${ACME_KEY_TYPE}" ]] ; then
    CERTBOT_OPT="${CERTBOT_OPT} --key-type ${ACME_KEY_TYPE}"
fi

cleanup() {
    rm -f /.acme-init
}

trap 'cleanup' EXIT

if [[ ! -d /etc/letsencrypt/live/${MASTER_FQDN} ]]; then
    touch /.acme-init
    # wait for the service to become healthy
    time_wait_for_running="${TIME_WAIT_FOR_RUNNING:-1}"
    sleep ${time_wait_for_running}
    certbot certonly --debug -vvv -n \
        --standalone \
        -d ${MASTER_FQDN} \
        ${CERTBOT_SERVER_OPT} \
        ${CERTBOT_OPT} \
        --agree-tos \
        --no-eff-email
fi

echo "certbot certificates"
certbot ${CERTBOT_SERVER_OPT} certificates || true

ln -s -f /etc/letsencrypt/live/${MASTER_FQDN}/fullchain.pem /etc/nginx/live-certs/server.cer
ln -s -f /etc/letsencrypt/live/${MASTER_FQDN}/privkey.pem /etc/nginx/live-certs/server.key
ln -s -f /reload-nginx /etc/letsencrypt/renewal-hooks/deploy/reload-nginx

