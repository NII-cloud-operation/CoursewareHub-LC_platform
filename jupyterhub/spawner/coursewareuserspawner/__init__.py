import os
from copy import copy

from dockerspawner import SwarmSpawner
from docker.types import Mount
from textwrap import dedent
from traitlets import (
    Any,
    Integer,
    Unicode,
    List,
    Dict,
    Tuple,
    default
)
from .traitlets import ResourceAllocationTrait
from tornado import gen
import requests_unixsocket


def get_user_id_default(spawner):
    """
    Get user ID via restuser service that runs on a master node.
    """
    session = requests_unixsocket.Session()
    r = session.post(
        'http+unix://%2Fvar%2Frun%2Frestuser.sock/{}'.format(spawner.user.name)
    )
    return r.json()['uid']


class CoursewareUserSpawner(SwarmSpawner):

    homedir = Unicode(
        "/home/{username}",
        config=True,
        help=dedent(
            """
            Format string for the path to the user's home directory
            inside the single-user container.
            The format string should include a `username` variable,
            which will be formatted with the user's username.
            """
        )
    )

    workdir = Unicode(
        "/home/{username}",
        config=True,
        help=dedent(
            """
            Format string for the path to the user's working directory
            inside the single-user container.
            The format string should include a `username` variable,
            which will be formatted with the user's username.
            """
        )
    )

    user_id = Integer(
        -1,
        help=dedent(
            """
            If system users are being used, then we need to know their user id
            in order to mount the home directory.

            User IDs are looked up in two ways:
            1. stored in the state dict (authenticator can write here)
            2. lookup via get_user_id function
            """
        )
    )

    user_mounts = List(
        config=True,
        help=dedent(
            """
            Mount options for a single-user container.
            List of docker.types.Mount objects.

            - {username} is expanded to the jupyterhub username
            - {homedir} is expanded to user's home directory in a container
            """
        )
    )

    extra_user_mounts = List(
        [],
        config=True,
        help=dedent(
            """
            Extra mount options for a single-user container.
            List of docker.types.Mount objects.

            - {username} is expanded to the jupyterhub username
            - {homedir} is expanded to user's home directory in a container
            """
        )
    )

    admin_data_mount_dirs = List(
        config=True,
        trait=Tuple(Unicode(), Unicode()),
        default_value=[
            ('textbook', 'textbook'),
            ('info', 'info')
        ],
        help=dedent(
            """
            List of directories to mount in the admin's single-user container.
            The item is tupple like (source, mount point).
            The mount point is relative path from /home/jupyer
            inside the single-user container.
            The source is relative path from admin_data_dir.
            If override admin_mounts this config is ignored.
            """
        )
    )

    admin_home_mount_dirs = List(
        config=True,
        trait=Tuple(Unicode(), Unicode()),
        default_value=[
            ('admin_tools', 'admin_tools')
        ],
        help=dedent(
            """
            List of directories to mount in the admin's single-user container.
            The item is tupple like (source, mount point).
            The mount point is relative path from home directory
            inside the single-user container.
            The source is relative path from admin_data_dir.
            If override admin_mounts this config is ignored.
            """
        )
    )

    non_admin_home_mount_dirs = List(
        config=True,
        trait=Tuple(Unicode(), Unicode()),
        default_value=[
            ('tools', 'tools'),
            ('textbook', 'textbook'),
            ('info', 'info')
        ],
        help=dedent(
            """
            List of directories to mount in the non-admin's
            single-user container.
            The item is tupple like (source, mount point).
            The mount point is relative path from home directory
            inside the single-user container.
            The source is relative path from admin_data_dir.
            If override non_admin_mounts this config is ignored.
            """
        )
    )

    admin_mounts = List(
        config=True,
        help=dedent(
            """
            Mount options for an admin's single-user container.
            List of docker.types.Mount objects.

            - {username} is expanded to the jupyterhub username
            - {homedir} is expanded to user's home directory in a container
            """
        )
    )

    extra_admin_mounts = List(
        [],
        config=True,
        help=dedent(
            """
            Extra mount options for an admin's single-user container.
            List of docker.types.Mount objects.

            - {username} is expanded to the jupyterhub username
            - {homedir} is expanded to user's home directory in a container
            """
        )
    )

    non_admin_mounts = List(
        config=True,
        help=dedent(
            """
            Mount options for an non-admin's single-user container.
            List of docker.types.Mount objects.

            - {username} is expanded to the jupyterhub username
            - {homedir} is expanded to user's home directory in a container
            """
        )
    )

    extra_non_admin_mounts = List(
        [],
        config=True,
        help=dedent(
            """
            Extra mount options for an non-admin's single-user container.
            List of docker.types.Mount objects.

            - {username} is expanded to the jupyterhub username
            - {homedir} is expanded to user's home directory in a container
            """
        )
    )

    get_user_id = Any(
        get_user_id_default,
        config=True,
        help=dedent(
            """
            An optional function that returns a user ID of a single-user
            notebook server in order to mount the home directory.
            The function takes a spawner object argument and returns a user ID.

            The default function calls restuser service via UNIX domain socket
            and returns the user ID.
            If the user is not found, restuser service adds a user.
            """
        )
    )

    group_resources = Dict(
        config=True,
        key_trait=Unicode,
        value_trait=ResourceAllocationTrait,
        default_value={},
        help=dedent(
            """
            Dict of group:`.traitlets.ResourceAllocation` to be applied
            to a single-user notebook server container.

            The key is user's group name.
            The `ResourceAllocation` object contains resource
            allocation settings for the group, and its priority.

            A spawner gets the settings using the user's group name as a key.
            If the user belong to more than one group the spawner use
            the settings with the smaller priority value.

            The allocation settings for each group are independent
            for each other.
            The spawner does not combine settings of different group .

            If `cpu_limit`, `mem_limit`, `cpu_guarantee` or `mem_guarantee`
            are configured this trait is ignored.

            For example:
            ```
            from coursewareuserspawner.traits import ResourceAllocation

            c.CoursewareUserSpawner.group_resources = {
                'group1': ResourceAllocation(
                    mem_limit = '2G',
                    cpu_limit = 2.0,
                    mem_guarantee = '1G',
                    cpu_guarantee = 0.5,
                    priority = 0
                ),
               'group2': ResourceAllocation(
                    mem_limit = '1G',
                    cpu_limit = 1.0,
                    priority = 10
                )
            }

            c.CoursewareUserSpawner.default_resources = ResourceAllocation(
                mem_limit = '1G',
                cpu_limit = 2.0,
                mem_guarantee = '1G',
                cpu_guarantee = 0.5
            )

            c.CoursewareUserSpawner.admin_resources = ResourceAllocation(
                mem_limit = '4G'
            )
            ```
            """
        )
    )

    default_resources = ResourceAllocationTrait(
        config=True,
        help=dedent(
            """
            Default resource allocations for a user's single-user container
            if the user group is not match any resource allocation settings
            of `group_resources`.
            """
        )
    )

    admin_resources = ResourceAllocationTrait(
        config=True,
        help=dedent(
            """
            The resource allocations for admin user's single-user container.
            This setting has the highest priority.
            """
        )
    )

    users_dir = Unicode(
        "/jupyter/users",
        config=True,
        help="Base path of users' home directory"
    )

    admin_data_dir = Unicode(
        "/jupyter/admin",
        config=True,
        help="Path of admin data directory"
    )

    @property
    def mounts(self):
        mounts = []
        mounts.extend(self.user_mounts)
        mounts.extend(self.extra_user_mounts)
        if self._is_admin():
            mounts.extend(self.admin_mounts)
            mounts.extend(self.extra_admin_mounts)
        else:
            mounts.extend(self.non_admin_mounts)
            mounts.extend(self.extra_non_admin_mounts)
        mounts = [self._render_mount_properties(m) for m in mounts]
        return sorted(mounts, key=lambda v: v['Target'])

    @default('user_mounts')
    def _default_user_mounts(self):
        mounts = []
        mounts.append(
            Mount(
                type="bind",
                target=self.homedir,
                source='/jupyter/users/{username}',
                read_only=False
            )
        )
        return mounts

    @default('admin_mounts')
    def _default_admin_mounts(self):
        mounts = []
        for mountpoint, source in self.admin_home_mount_dirs:
            mounts.append(
                Mount(
                    type="bind",
                    target=os.path.join(self.homedir, mountpoint),
                    source=os.path.join(self.admin_data_dir, source),
                    read_only=False
                )
            )
        for mountpoint, source in self.admin_data_mount_dirs:
            mounts.append(
                Mount(
                    type="bind",
                    target=os.path.join('/home/jupyter', mountpoint),
                    source=os.path.join(self.admin_data_dir, source),
                    read_only=False
                )
            )
        mounts.append(
            Mount(
                type="bind",
                target='/home/jupyter/workspace',
                source=self.users_dir,
                read_only=False
            )
        )
        mounts.append(
            Mount(
                type="bind",
                target='/jupyter/admin',
                source=self.admin_data_dir,
                read_only=False
            )
        )
        return mounts

    @default('non_admin_mounts')
    def _default_non_admin_mounts(self):
        mounts = []
        for mountpoint, source in self.non_admin_home_mount_dirs:
            mounts.append(
                Mount(
                    type="bind",
                    target=os.path.join(self.homedir, mountpoint),
                    source=os.path.join(self.admin_data_dir, source),
                    read_only=True
                )
            )
        return mounts

    def _render_mount_properties(self, m):
        m = copy(m)
        for k, v in m.items():
            if isinstance(v, str):
                v = self.format_string(v)
                if k == 'Source' or k == 'Target':
                    v = os.path.normpath(v)
                m[k] = v
        return m

    def get_env(self):
        env = super(CoursewareUserSpawner, self).get_env()
        # relies on NB_USER and NB_UID handling in jupyter/docker-stacks
        env.update(dict(
            USER=self.user.name, # deprecated
            NB_USER=self.user.name,
            USER_ID=self.user_id, # deprecated
            NB_UID=self.user_id,
            HOME=self.format_string(self.homedir),
        ))
        if os.environ.get('DEBUG', 'no') in ['yes', '1']:
            env.update(dict(
                REPO_DIR=self.format_string(self.homedir),
            ))
        # Fix 20180802
        if self._is_admin():
            env['GRANT_SUDO'] = 'yes'
        return env

    @default('user_id')
    def _default_user_id(self):
        """
        Get user_id via get_user_id function.

        If the authenticator stores user_id in the user state dict,
        this will never be called.
        """
        return self.get_user_id(self)

    def load_state(self, state):
        super().load_state(state)
        if 'user_id' in state:
            self.user_id = state['user_id']

    def get_state(self):
        state = super().get_state()
        if self.user_id >= 0:
            state['user_id'] = self.user_id
        return state

    def _get_resource_config(self, config_name):
        resources = None
        groups = [g.name for g in self.user.groups]
        admin = self._is_admin()
        self.log.debug(('_get_resource_config: config=%s, '
                        'user=%s, groups=%s, admin=%s'),
                       config_name, self.user.name, str(groups), str(admin))

        if admin and self.admin_resources is not None:
            resources = self.admin_resources
        else:
            config_list = self.group_resources.items()
            config_list = [(g, c) for g, c in config_list
                           if (g in groups and
                               g != 'admin' and g != 'default' and
                               c is not None)]
            config_list = sorted(config_list, key=lambda x: x[1].priority)
            if config_list:
                resources = config_list[0][1]

        if resources is None:
            resources = self.default_resources

        self.log.debug(('_get_resource_config result: config=%s, '
                        'user=%s, groups=%s, admin=%s, resources=%s'),
                       config_name, self.user.name, str(groups),
                       str(admin), str(resources))
        config_value = None
        if resources is not None:
            config_value = getattr(resources, config_name)
        self.log.debug('resource allocation: user=%s, %s=%s',
                       self.user.name, config_name, config_value)
        return config_value

    @default('cpu_limit')
    def _default_cpu_limit(self):
        return self._get_resource_config('cpu_limit')

    @default('cpu_guarantee')
    def _default_cpu_guarantee(self):
        return self._get_resource_config('cpu_guarantee')

    @default('mem_limit')
    def _default_mem_limit(self):
        return self._get_resource_config('mem_limit')

    @default('mem_guarantee')
    def _default_mem_guarantee(self):
        return self._get_resource_config('mem_guarantee')

    @gen.coroutine
    def create_object(self):
        # systemuser image must be started as root
        # relies on NB_UID and NB_USER handling in docker-stacks
        self.extra_container_spec = {
            'workdir': self.format_string(self.workdir),
            'user': '0'
        }

        return (yield super(CoursewareUserSpawner, self).create_object())

    def _is_admin(self):
        return self.user.admin
