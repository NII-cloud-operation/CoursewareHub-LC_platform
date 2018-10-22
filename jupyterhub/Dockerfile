FROM jupyterhub/jupyterhub:0.8.1

# dind
RUN apt-get update && apt-get install -y make && apt-get autoclean && apt-get clean && apt-get autoremove
RUN curl -fsSL https://get.docker.com/ | sh

# Authenticator
RUN pip --no-cache-dir install git+https://github.com/cwaldbieser/jhub_remote_user_authenticator.git

# Spawner
RUN mkdir /tmp/spawner
ADD ./spawner /tmp/spawner/
RUN pip --no-cache-dir install dockerspawner && \
    cd /tmp/spawner; pip --no-cache-dir install .

# Resources
RUN mkdir /var/jupyterhub
ADD jupyterhub_config.py /srv/jupyterhub/
