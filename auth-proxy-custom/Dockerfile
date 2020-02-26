ARG BASE_CONTAINER=niicloudoperation/auth-proxy-common
FROM $BASE_CONTAINER

# Setup simplesamlphp config
ARG MASTER_FQDN
ARG AUTH_FQDN="nbhub.ecloud.nii.ac.jp"
RUN if [ -z "${MASTER_FQDN}" ]; then exit 1; fi && \
    if [ -n "${AUTH_FQDN}" ]; then \
      sed -i "s;'entityID' => .*;'entityID' => 'https://${MASTER_FQDN}/simplesaml/module.php',;" \
      /var/www/simplesamlphp/config/authsources.php; \
      sed -i "s;'idp' => .*;'idp' => 'https://${AUTH_FQDN}/simplesaml/saml2/idp/metadata.php',;" \
      /var/www/simplesamlphp/config/authsources.php; \
      sed -i "s;'src' => .*;'src' => 'https://${AUTH_FQDN}/simplesaml/saml2/idp/metadata.php',;" \
      /var/www/simplesamlphp/config/config-metarefresh.php; \
    else \
      rm /var/www/simplesamlphp/modules/metarefresh/enable; \
    fi

