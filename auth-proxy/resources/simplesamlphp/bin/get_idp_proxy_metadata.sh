#/bin/bash

idp_proxy="$1"

idp_proxy_metadata_path=metadata/idp-proxy.xml
cd /var/www/simplesamlphp
curl --insecure -o $idp_proxy_metadata_path https://$idp_proxy/simplesaml/saml2/idp/metadata.php 
sed -i "s|#IDP_PROXY_XML#|array('type' => 'xml', 'file' => '$idp_proxy_metadata_path')|" config/config.php
