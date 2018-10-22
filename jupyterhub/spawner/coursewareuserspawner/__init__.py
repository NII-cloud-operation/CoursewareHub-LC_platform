import pwd
import os

from dockerspawner import DockerSpawner
from textwrap import dedent
from traitlets import (
    Integer,
    Unicode,
)


class CoursewareUserSpawner(DockerSpawner):

    userlist_path = Unicode(
        "/srv/jupyterhub_users/userlist",
        config=True,
        help=dedent(
            """
            Userlist file of Courseware
            """
        )
    )

    image_homedir_format_string = Unicode(
        "/home/{username}",
        config=True,
        help=dedent(
            """
            Format string for the path to the user's home directory
            inside the image.  The format string should include a
            `username` variable, which will be formatted with the
            user's username.
            """
        )
    )

    user_id = Integer(-1,
        help=dedent(
            """
            If system users are being used, then we need to know their user id
            in order to mount the home directory.
            User IDs are looked up in two ways:
            1. stored in the state dict (authenticator can write here)
            2. lookup via pwd
            """
        )
    )

    @property
    def homedir(self):
        """
        Path to the user's home directory in the docker image.
        """
        return self.image_homedir_format_string.format(username=self.user.name)

    @property
    def volume_mount_points(self):
        """
        Volumes are declared in docker-py in two stages.  First, you declare
        all the locations where you're going to mount volumes when you call
        create_container.
        Returns a list of all the values in self.volumes or
        self.read_only_volumes.
        """
        mount_points = super(CoursewareUserSpawner, self).volume_mount_points
        mount_points.append(self.homedir)
        return mount_points

    @property
    def volume_binds(self):
        """
        The second half of declaring a volume with docker-py happens when you
        actually call start().  The required format is a dict of dicts that
        looks like:
        {
            host_location: {'bind': container_location, 'ro': True}
        }
        """
        volumes = super(CoursewareUserSpawner, self).volume_binds
        with open(self.userlist_path, 'r') as user_file:
            usersstring = user_file.read()

        if self._is_admin():
            volumes['/jupyter/admin/{user}'.format(user=self.user.name)] = {
                'bind': self.homedir,
                'ro': False
            }
            # new (k8s) directory structure
            for dirname in ['textbook', 'info']:
                cpath = os.path.join('/home/jupyter', dirname)
                hpath = os.path.join('/jupyter/admin', dirname)
                volumes[hpath] = {'bind': cpath, 'ro': False}
            volumes['/jupyter/users'] = {'bind': '/home/jupyter/workspace', 'ro': False}
            volumes['/jupyter/admin'] = {'bind': '/jupyter/admin', 'ro': False}
        else:
            volumes['/jupyter/users/{user}'.format(user=self.user.name)] = {
                'bind': self.homedir,
                'ro': False
            }
            for dirname in ['textbook', 'tools', 'info']:
                path = os.path.join('/jupyter/admin', dirname)
                volumes[path] = {'bind': path, 'ro': True}
        return volumes

    def get_env(self):
        env = super(CoursewareUserSpawner, self).get_env()
        # relies on NB_USER and NB_UID handling in jupyter/docker-stacks
        env.update(dict(
            USER=self.user.name, # deprecated
            NB_USER=self.user.name,
            USER_ID=self.user_id, # deprecated
            NB_UID=self.user_id,
            HOME=self.homedir,
        ))
        # Fix 20180802
        if self._is_admin():
            env['GRANT_SUDO'] = 'yes'
        return env

    def _user_id_default(self):
        """
        Get user_id from pwd lookup by name
        If the authenticator stores user_id in the user state dict,
        this will never be called, which is necessary if
        the system users are not on the Hub system (i.e. Hub itself is in a container).
        """
        return pwd.getpwnam(self.user.name).pw_uid

    def load_state(self, state):
        super().load_state(state)
        if 'user_id' in state:
            self.user_id = state['user_id']

    def get_state(self):
        state = super().get_state()
        if self.user_id >= 0:
            state['user_id'] = self.user_id
        return state

    def start(self, image=None, extra_create_kwargs=None,
        extra_start_kwargs=None, extra_host_config=None):
        """start the single-user server in a docker container"""
        if extra_create_kwargs is None:
            extra_create_kwargs = {}

        extra_create_kwargs.setdefault('working_dir', self.homedir)
        # systemuser image must be started as root
        # relies on NB_UID and NB_USER handling in docker-stacks
        extra_create_kwargs.setdefault('user', '0')

        return super(CoursewareUserSpawner, self).start(
            image=image,
            extra_create_kwargs=extra_create_kwargs,
            extra_start_kwargs=extra_start_kwargs,
            extra_host_config=extra_host_config
        )

    def _is_admin(self):
        with open(self.userlist_path, 'r') as user_file:
            usersstring = user_file.read()
        return self.user.name + ' admin' in usersstring
