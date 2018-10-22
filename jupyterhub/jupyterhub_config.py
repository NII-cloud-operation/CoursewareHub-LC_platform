import os

# Configuration file for jupyterhub.

## The ip for this process
c.JupyterHub.hub_ip = os.environ['HUB_IP']

## The public facing ip of the whole application (the proxy)
c.JupyterHub.ip = '0.0.0.0'

## The class to use for spawning single-user servers.
#
#  Should be a subclass of Spawner.
#c.JupyterHub.spawner_class = 'jupyterhub.spawner.LocalProcessSpawner'
c.JupyterHub.spawner_class = 'coursewareuserspawner.CoursewareUserSpawner'
c.DockerSpawner.container_ip = "0.0.0.0"
c.DockerSpawner.container_image = os.environ['CONTAINER_IMAGE']

c.JupyterHub.authenticator_class = "jhub_remote_user_authenticator.remote_user_auth.RemoteUserLocalAuthenticator"
c.LocalAuthenticator.add_user_cmd = ["adduser", "-q", "--gecos", "\"\"", "--home", "/jupyter/users/USERNAME", "--disabled-password"]

## If set to True, will attempt to create local system users if they do not exist
#  already.
#
#  Supports Linux and BSD variants only.
c.LocalAuthenticator.create_system_users = True

c.JupyterHub.logo_file = '/var/jupyterhub/logo.png'
