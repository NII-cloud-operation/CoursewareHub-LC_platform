FROM ubuntu:14.04

# Update cache and install base packages
RUN set -x \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 00A6F0A3C300EE8C \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C \
    #&& apt-key adv --recv-keys --keyserver keyserver.ubuntu.com \
    && apt-get update \
    && apt-get -y --force-yes install software-properties-common
RUN set -x \
    && add-apt-repository ppa:nginx/stable \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update \
    && apt-get -y --force-yes install curl git unzip \
    && apt-get -y --force-yes --no-install-recommends --no-install-suggests install \
        nginx \
        php5.6-cli \
        php5.6-fpm \
        php5.6-common \
        php5.6-xml \
        php5.6-pgsql \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    # Install simplesamlphp
    && cd /var/www \
    && curl -Lo /var/www/downloaded-simplesamlphp.tar.gz https://simplesamlphp.org/download?latest \
    && tar xvfz downloaded-simplesamlphp.tar.gz \
    && mv $( ls | grep simplesaml | grep -v *tar.gz ) simplesamlphp \
    && rm /var/www/downloaded-simplesamlphp.tar.gz 

# Configure PHP settings
RUN perl -pi -e 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php/5.6/fpm/php.ini
RUN perl -pi -e 's/allow_url_fopen = Off/allow_url_fopen = On/g' /etc/php/5.6/fpm/php.ini
RUN perl -pi -e 's/expose_php = On/expose_php = Off/g' /etc/php/5.6/fpm/php.ini

# Copy nginx.conf
COPY resources/nginx/nginx.conf /etc/nginx/

# nginx keys
#COPY resources/keys/auth-proxy.chained.cer /etc/nginx/certs/
#COPY resources/keys/auth-proxy.key /etc/nginx/certs/

# Setup simplesamlphp
COPY resources/simplesamlphp/config/config.php /var/www/simplesamlphp/config
COPY resources/simplesamlphp/config/authsources.php /var/www/simplesamlphp/config
COPY resources/simplesamlphp/metadata/saml20-idp-remote.php /var/www/simplesamlphp/metadata
# simplesamlphp keys
RUN set -x \
    && cd /var/www/simplesamlphp/cert \
    && openssl req -newkey rsa:2048 -new -x509 -nodes \
         -out auth-proxy.crt \
         -keyout auth-proxy.key \
         -subj "/C=JP/ST=Tokyo/L=Chiyoda-ku/O=NII/CN=auth-proxy"
#COPY resources/keys/auth-proxy.cer /var/www/simplesamlphp/cert/
#COPY resources/keys/auth-proxy.key /var/www/simplesamlphp/cert/

# Change owner
RUN set -x \
    && chown -R www-data:www-data /var/www/simplesamlphp

# Boot up Nginx, and PHP5-FPM when container is started
CMD service php5.6-fpm start && service nginx start

# Set the current working directory
WORKDIR /var/www/html

# Expose port 80
EXPOSE 80
EXPOSE 443

