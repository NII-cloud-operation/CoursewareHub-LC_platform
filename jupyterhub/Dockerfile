FROM jupyterhub/jupyterhub:0.8.1

# dind
RUN apt-get update && apt-get install -y make && apt-get autoclean && apt-get clean && apt-get autoremove
RUN curl -fsSL https://get.docker.com/ | sh
