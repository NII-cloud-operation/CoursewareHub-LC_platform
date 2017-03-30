#/bin/bash

idp_proxy=$1

cd /var/www/simplesamlphp/metadata
curl --insecure -o idp_proxy.xml https://$idp_proxy/simplesaml/saml2/idp/metadata.php 
