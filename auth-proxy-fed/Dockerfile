ARG BASE_CONTAINER=niicloudoperation/auth-proxy-common
FROM $BASE_CONTAINER

# Install simplesamlphp-module-attributeaggregator
RUN set -x \
    && apt-get -y --force-yes --no-install-recommends --no-install-suggests install \
       php7.1-curl \
       php7.1-mcrypt \
       php7.1-mbstring \
       php7.1-gmp \
       php7.1-soap \
       php7.1-ldap \
       composer \
    && cd /var/www/simplesamlphp \
    && composer config repositories.attributeaggregator vcs https://github.com/NII-cloud-operation/simplesamlphp-module-attributeaggregator \
    && composer require niif/simplesamlphp-module-attributeaggregator:dev-2.x-gakunin-cloud-gateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add Federation configuration
ARG SIMPLESAMLPHP_METAREFRESH_CONFIG="config-metarefresh.php"
COPY resources/simplesamlphp/config/config.php /var/www/simplesamlphp/config
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
