FROM jupyterhub/jupyterhub:5.2 AS builder

# dev tools
RUN apt-get update && \
    apt-get install -y \
        gcc \
        libpq-dev \
        git \
        python3-dev && \
    apt-get autoclean && apt-get clean && apt-get autoremove

# freeze version of pip packages from upstream image
RUN python3 -m pip list --format freeze > /tmp/requirements

WORKDIR /tmp

# Authenticator
RUN python3 -m pip wheel --wheel-dir wheelhouse --constraint requirements \
    git+https://github.com/cwaldbieser/jhub_remote_user_authenticator.git

# Spawner
ADD ./spawner /tmp/spawner/
ADD ./cwh-authenticator /tmp/cwh-authenticator/
ADD ./cwh-repo2docker /tmp/cwh-repo2docker/
RUN python3 -m pip wheel --wheel-dir wheelhouse --constraint requirements \
        git+https://github.com/jupyterhub/dockerspawner.git \
        /tmp/spawner \
        /tmp/cwh-authenticator \
        /tmp/cwh-repo2docker

# DB
RUN python3 -m pip wheel --wheel-dir wheelhouse --constraint requirements \
    psycopg2

# PyYAML
RUN python3 -m pip wheel --wheel-dir wheelhouse --constraint requirements \
    PyYAML

# jsonschema
RUN python3 -m pip wheel --wheel-dir wheelhouse --constraint requirements \
    jsonschema

# idle-culler
RUN python3 -m pip wheel --wheel-dir wheelhouse --constraint requirements \
    jupyterhub-idle-culler

FROM jupyterhub/jupyterhub:5.2

# dind
RUN apt-get update && \
    apt-get install -y make && \
    apt-get autoclean && apt-get clean && apt-get autoremove && \
    curl -fsSL https://get.docker.com/ | sh

# DB
RUN apt-get update && \
    apt-get install -y \
        libpq5 && \
    apt-get autoclean && apt-get clean && apt-get autoremove

# install the wheels from first stage
RUN --mount=type=cache,from=builder,source=/tmp/wheelhouse,target=/tmp/wheelhouse \
    python3 -m pip install --no-cache --no-deps /tmp/wheelhouse/*

# Resources
RUN mkdir /var/jupyterhub
ADD jupyterhub_config.py /srv/jupyterhub/
ADD cwh_repo2docker_config.py /srv/jupyterhub/
ADD resources-schema.json /srv/jupyterhub/
ADD get_user_id.sh /
RUN chmod +x /get_user_id.sh
RUN apt-get install -y netcat-openbsd \
    && apt-get autoremove -y \
    && apt-get clean -y

EXPOSE 8000
EXPOSE 8081
