FROM ubuntu:24.04

ARG SIMPLESAMLPHP_VERSION="2.4.4"
ARG ATTRIBUTE_AGGREGATOR_URL="https://github.com/NII-cloud-operation/simplesamlphp-module-attributeaggregator"
ARG ATTRIBUTE_AGGREGATOR_BRANCH="dev-2.x-gakunin-cloud-gateway"

# Update cache and install base packages
ENV DEBIAN_FRONTEND=noninteractive
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN apt-get update && apt-get install -y gnupg2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN set -x \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 00A6F0A3C300EE8C \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
    #&& apt-key adv --recv-keys --keyserver keyserver.ubuntu.com \
    && apt-get update \
    && apt-get -y install \
        software-properties-common \
        pwgen \
        curl \
        git \
        unzip \
        supervisor \
        cron \
	gnupg2 \
	ca-certificates \
	lsb-release \
	ubuntu-keyring \
        patch \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
RUN set -x \
    && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
        | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
    && gpg --dry-run --quiet --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg | grep 573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
        | tee /etc/apt/sources.list.d/nginx.list \
    && echo "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
        | tee /etc/apt/preferences.d/99nginx \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get -y --no-install-recommends --no-install-suggests install \
        nginx \
        php8.4-cli \
        php8.4-fpm \
        php8.4-common \
        php8.4-xml \
        php8.4-pgsql \
        php8.4-sqlite3 \
    && php8.4 -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php8.4 -r "if (hash_file('sha384', 'composer-setup.php') === '$(curl -q https://composer.github.io/installer.sig)') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php8.4 composer-setup.php \
    && php8.4 -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && mkdir -p /run/php \
    # Install simplesamlphp
    && mkdir -p /var/www \
    && cd /var/www \
    && curl -Lo /var/www/downloaded-simplesamlphp.tar.gz https://github.com/simplesamlphp/simplesamlphp/releases/download/v${SIMPLESAMLPHP_VERSION}/simplesamlphp-${SIMPLESAMLPHP_VERSION}-full.tar.gz \
    && tar xvfz downloaded-simplesamlphp.tar.gz \
    && mv $( ls | grep simplesaml | grep -v *tar.gz ) simplesamlphp \
    && rm /var/www/downloaded-simplesamlphp.tar.gz \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install lti-1-3-php-library
COPY resources/composer.json /var/www/composer.json
RUN cd /var/www && composer install --no-dev

# Configure PHP settings
RUN perl -pi -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/8.4/fpm/php.ini && \
    perl -pi -e 's/allow_url_fopen = Off/allow_url_fopen = On/g' /etc/php/8.4/fpm/php.ini && \
    perl -pi -e 's/expose_php = On/expose_php = Off/g' /etc/php/8.4/fpm/php.ini && \
    perl -pi -e 's/;?\s*session\.gc_maxlifetime\s*=\s*.+/session.gc_maxlifetime = 10800/g' /etc/php/8.4/fpm/php.ini

# Prepare nginx configuration
RUN mkdir /etc/nginx/certs

# Setup simplesamlphp
COPY resources/simplesamlphp/bin/get_idp_proxy_metadata.sh /var/www/simplesamlphp/bin
COPY resources/simplesamlphp/bin/remove_idp_proxy_metadata.sh /var/www/simplesamlphp/bin
COPY resources/simplesamlphp/templates/selectidp-dropdown.twig /var/www/simplesamlphp/templates
COPY resources/simplesamlphp/templates/selectidp-embedded-wayf-start.twig /var/www/simplesamlphp/templates/includes
COPY resources/simplesamlphp/templates/selectidp-embedded-wayf-end.twig /var/www/simplesamlphp/templates/includes

# simplesamlphp keys
RUN set -x \
    && cd /var/www/simplesamlphp/cert \
    && openssl req -newkey rsa:2048 -new -x509 -nodes \
         -out auth-proxy.cer \
         -keyout auth-proxy.key \
         -subj "/C=JP/ST=Tokyo/L=Chiyoda-ku/O=NII/CN=auth-proxy"

# simplesamlphp metarefresh module
RUN set -x \
    && mkdir -p /var/www/simplesamlphp/metadata/idp-proxy

# Patch simplesamlphp
COPY resources/simplesamlphp/simplesamlphp.patch /tmp/
RUN set -x \
    && cd /var/www/simplesamlphp \
    && patch -p1 < /tmp/simplesamlphp.patch \
    && rm -f /tmp/simplesamlphp.patch

# Install simplesamlphp-module-attributeaggregator
RUN set -x \
    && apt-get update \
    && apt-get -y --force-yes --no-install-recommends --no-install-suggests install \
       php8.4-curl \
       php8.4-mbstring \
       php8.4-gmp \
       php8.4-soap \
       php8.4-ldap \
       composer \
    && cd /var/www/simplesamlphp \
    && composer config repositories.attributeaggregator "{\"type\": \"vcs\", \"url\": \"${ATTRIBUTE_AGGREGATOR_URL}\", \"no-api\": true}" \
    && composer require --update-no-dev niif/simplesamlphp-module-attributeaggregator:${ATTRIBUTE_AGGREGATOR_BRANCH} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Change owner
RUN set -x \
    && chown -R www-data:www-data /var/www/simplesamlphp /var/www/vendor \
    && chmod a+x /var/www/simplesamlphp/bin/get_idp_proxy_metadata.sh

# supervisord
COPY resources/supervisord.conf /etc/

# Install jinja2-cli and certbot
RUN set -x \
    && apt-get update \
    && apt-get -y --no-install-recommends --no-install-suggests install \
       python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /opt/venv \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir jinja2-cli certbot

ENV PATH=/opt/venv/bin:$PATH

# Install config template files
COPY resources/etc/templates /etc/templates

# Metadata signing cerfiticates
ENV SIGNING_CERT_DIR=/var/www/simplesamlphp/signing-cert \
    GAKUNIN_SIGNER_FILENAME=gakunin-signer.cer \
    GAKUNIN_SIGNER_SHA256=5E:D6:A8:C5:E9:30:49:3F:B4:BA:77:54:6A:FB:66:BA:14:7D:CB:50:5B:EF:0F:D9:7C:26:04:C2:D9:36:FD:81 \
    GAKUNINTEST_SIGNER_FILENAME=gakunintest-signer.cer \
    GAKUNINTEST_SIGNER_SHA256=FA:11:11:5B:EC:13:4D:55:85:AF:60:32:E1:6C:01:01:EF:9C:A0:6B:17:8C:8B:9C:7F:2B:69:41:EB:68:30:1E \
    ORTHROS_SIGNER_FILENAME=orhtoros-signer.cer \
    ORTHROS_SIGNER_SHA256=C7:AE:69:98:AC:E7:6A:C2:83:CC:5F:99:0A:C1:3C:A1:62:3D:F6:84:AA:7B:08:30:37:2D:DA:6B:82:AB:BA:44 \
    ORTHROSSTG_SIGNER_FILENAME=orthrosstg-signer.cer \
    ORTHROSSTG_SIGNER_SHA256=A3:AF:64:82:1B:BF:C9:28:E9:E7:0D:5E:7C:04:41:1C:2D:87:47:1F:45:1D:24:32:B6:31:FF:91:B5:71:53:0D
RUN mkdir -p $SIGNING_CERT_DIR && \
    curl -q -L -o ${SIGNING_CERT_DIR}/${GAKUNIN_SIGNER_FILENAME} https://metadata.gakunin.nii.ac.jp/gakunin-signer-2017.cer && \
    curl -q -L -o ${SIGNING_CERT_DIR}/${GAKUNINTEST_SIGNER_FILENAME} https://metadata.gakunin.nii.ac.jp/gakunin-test-signer-2020.cer && \
    curl -q -L -o ${SIGNING_CERT_DIR}/${ORTHROS_SIGNER_FILENAME} https://core.orthros.gakunin.nii.ac.jp/metadata/orthros-signer-2025.cer && \
    curl -q -L -o ${SIGNING_CERT_DIR}/${ORTHROSSTG_SIGNER_FILENAME} https://core-stg.orthros.gakunin.nii.ac.jp/metadata/orthrosstg-signer-2025.cer && \
    test "${GAKUNIN_SIGNER_SHA256}" = \
         "$(openssl x509 -fingerprint -sha256 -noout -in ${SIGNING_CERT_DIR}/${GAKUNIN_SIGNER_FILENAME} | awk -F = '{print $2}')" && \
    test "${GAKUNINTEST_SIGNER_SHA256}" = \
         "$(openssl x509 -fingerprint -sha256 -noout -in ${SIGNING_CERT_DIR}/${GAKUNINTEST_SIGNER_FILENAME} | awk -F = '{print $2}')" && \
    test "${ORTHROS_SIGNER_SHA256}" = \
         "$(openssl x509 -fingerprint -sha256 -noout -in ${SIGNING_CERT_DIR}/${ORTHROS_SIGNER_FILENAME} | awk -F = '{print $2}')" && \
    test "${ORTHROSSTG_SIGNER_SHA256}" = \
         "$(openssl x509 -fingerprint -sha256 -noout -in ${SIGNING_CERT_DIR}/${ORTHROSSTG_SIGNER_FILENAME} | awk -F = '{print $2}')"

# Set the current working directory
WORKDIR /var/www/html

# Expose port 80, 443
EXPOSE 80
EXPOSE 443

COPY --chmod=755 resources/scripts/start.sh /
COPY --chmod=755 resources/scripts/acme-init.sh /
COPY --chmod=755 resources/scripts/acme-renew.sh /
COPY --chmod=755 resources/scripts/reload-nginx /
COPY --chmod=755 resources/scripts/healthcheck.sh /

HEALTHCHECK --interval=30s --timeout=3s --retries=3 --start-period=10s --start-interval=1s CMD /healthcheck.sh

COPY --chown=www-data:www-data resources/htdocs/php /var/www/htdocs/php
COPY --chown=www-data:www-data resources/html /var/www/htdocs/html
COPY --chown=www-data:www-data resources/templates /var/www/templates
COPY --chown=www-data:www-data resources/bin /var/www/bin
COPY --chown=www-data:www-data resources/lib /var/www/lib

CMD ["/start.sh"]
