ARG BASE_CONTAINER=niicloudoperation/auth-proxy-common
FROM $BASE_CONTAINER

# Install simplesamlphp-module-attributeaggregator
RUN set -x \
    && apt-get update \
    && apt-get -y --force-yes --no-install-recommends --no-install-suggests install \
       php7.3-curl \
       php7.3-mbstring \
       php7.3-gmp \
       php7.3-soap \
       php7.3-ldap \
       composer \
    && cd /var/www/simplesamlphp \
    && composer config repositories.attributeaggregator '{"type": "vcs", "url": "https://github.com/NII-cloud-operation/simplesamlphp-module-attributeaggregator", "no-api": true}' \
    && composer require niif/simplesamlphp-module-attributeaggregator:dev-2.x-gakunin-cloud-gateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add Federation configuration
ARG SIMPLESAMLPHP_CONFIG="config.php"
ARG SIMPLESAMLPHP_METAREFRESH_CONFIG="config-metarefresh.php"
COPY resources/simplesamlphp/config/${SIMPLESAMLPHP_CONFIG} /var/www/simplesamlphp/config/config.php
COPY resources/simplesamlphp/config/authsources.php /var/www/simplesamlphp/config
COPY resources/simplesamlphp/config/${SIMPLESAMLPHP_METAREFRESH_CONFIG} /var/www/simplesamlphp/config/config-metarefresh.php
COPY resources/simplesamlphp/templates/selectidp-dropdown.php /var/www/simplesamlphp/templates/selectidp-dropdown.php
COPY resources/saml/www/sp/discoresp.php /var/www/simplesamlphp/modules/saml/www/sp/discoresp.php

# Setup simplesamlphp config
ARG MASTER_FQDN
ARG DS_FQDN="ds.gakunin.nii.ac.jp"
ARG CG_FQDN="cg.gakunin.jp"
RUN if [ -z "${MASTER_FQDN}" ]; then exit 1; fi && \
    sed -i "s;'entityID' => .*;'entityID' => 'https://${MASTER_FQDN}/shibboleth-sp',;" \
    /var/www/simplesamlphp/config/authsources.php && \
    sed -i "s;'entityId' => .*;'entityId' => 'https://${CG_FQDN}/idp/shibboleth',;" \
    /var/www/simplesamlphp/config/config.php && \
    sed -i "s,var embedded_wayf_URL = .*,var embedded_wayf_URL = \"https://${DS_FQDN}/WAYF/embedded-wayf.js\";," \
    /var/www/simplesamlphp/templates/selectidp-dropdown.php && \
    sed -i "s,var wayf_URL = .*,var wayf_URL = \"https://${DS_FQDN}/WAYF\";," \
    /var/www/simplesamlphp/templates/selectidp-dropdown.php && \
    sed -i "s,var wayf_sp_handlerURL = .*,var wayf_sp_handlerURL = \"https://${MASTER_FQDN}/simplesaml/module.php/saml/sp/discoresp.php\";," \
    /var/www/simplesamlphp/templates/selectidp-dropdown.php

