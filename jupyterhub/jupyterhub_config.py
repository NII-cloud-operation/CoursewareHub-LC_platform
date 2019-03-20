import os

# Configuration file for jupyterhub.

## The ip for this process
c.JupyterHub.hub_ip = '0.0.0.0'

## The public facing ip of the whole application (the proxy)
c.JupyterHub.ip = '0.0.0.0'

## The class to use for spawning single-user servers.
#
#  Should be a subclass of Spawner.
c.JupyterHub.spawner_class = 'coursewareuserspawner.CoursewareUserSpawner'
c.DockerSpawner.container_ip = "0.0.0.0"
c.DockerSpawner.container_image = os.environ['CONTAINER_IMAGE']
c.DockerSpawner.network_name = os.environ['BACKEND_NETWORK']

c.JupyterHub.authenticator_class = "jhub_remote_user_authenticator.remote_user_auth.RemoteUserLocalAuthenticator"
c.LocalAuthenticator.create_system_users = True
c.LocalAuthenticator.add_user_cmd = ["/get_user_id.sh"]

c.JupyterHub.logo_file = '/var/jupyterhub/logo.png'

c.JupyterHub.admin_access = True if os.environ.get('ADMIN_ACCESS', '1') in ('yes', '1') else False

if 'CONCURRENT_SPAWN_LIMIT' in os.environ:
    c.JupyterHub.concurrent_spawn_limit = int(os.environ['CONCURRENT_SPAWN_LIMIT'])
if 'SPAWNER_HTTP_TIMEOUT' in os.environ:
    c.Spawner.http_timeout = int(os.environ['SPAWNER_HTTP_TIMEOUT'])
if 'SPAWNER_START_TIMEOUT' in os.environ:
    c.Spawner.start_timeout = int(os.environ['SPAWNER_START_TIMEOUT'])

if 'CPU_LIMIT' in os.environ:
    c.Spawner.cpu_limit = float(os.environ['CPU_LIMIT'])
if 'CPU_GUARANTEE' in os.environ:
    c.Spawner.cpu_guarantee = float(os.environ['CPU_GUARANTEE'])
if 'MEM_LIMIT' in os.environ:
    c.Spawner.mem_limit = os.environ['MEM_LIMIT']
if 'MEM_GUARANTEE' in os.environ:
    c.Spawner.mem_guarantee = os.environ['MEM_GUARANTEE']

# DB
pg_user = os.environ['POSTGRES_ENV_JPY_PSQL_USER']
pg_pass = os.environ['POSTGRES_ENV_JPY_PSQL_PASSWORD']
pg_host = os.environ['POSTGRES_PORT_5432_TCP_ADDR']
c.JupyterHub.db_url = 'postgresql://{}:{}@{}:5432/jupyterhub'.format(
    pg_user,
    pg_pass,
    pg_host,
)
