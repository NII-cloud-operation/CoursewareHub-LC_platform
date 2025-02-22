import os
import re
import sys

from jupyterhub.spawner import Spawner
from coursewareuserspawner import CoursewareUserSpawner
from jinja2 import Environment, BaseLoader
from traitlets import (
    List,
    Tuple,
    Unicode,
)
from tornado import web

from .registry import get_registry, split_image_name


class Repo2DockerSpawner(CoursewareUserSpawner):
    """
    A custom spawner for using Docker images built with cwh-repo2docker.
    """

    image_form_template = Unicode(
        """
        <style>
            #image-list {
                max-height: 600px;
                overflow: auto;
            }
            .image-info {
                font-weight: normal;
            }
        </style>
        <div class='form-group' id='image-list'>
        {% for image in image_list %}
        <label for='image-item-{{ loop.index0 }}' class='form-control input-group'>
            <div class='col-md-1'>
                {% if image.selected %}
                <input type='radio' name='image' id='image-item-{{ loop.index0 }}' value='{{ registry_host }}/{{ image.image_name }}' checked/>
                {% else %}
                <input type='radio' name='image' id='image-item-{{ loop.index0 }}' value='{{ registry_host }}/{{ image.image_name }}' />
                {%- endif %}
            </div>
            <div class='col-md-11'>
                <strong>{{ image.display_name }}</strong>
                <div class='row image-info'>
                    <div class='col-md-4'>
                        Repository:
                    </div>
                    {% if image.repo %}
                    <div class='col-md-8'>
                        <a href="{{ image.repo }}" target="_blank">{{ image.repo }}</a>
                    </div>
                    {% else %}
                    <div class='col-md-8'>
                        -
                    </div>
                    {%- endif %}
                </div>
                <div class='row image-info'>
                    <div class='col-md-4'>
                        Reference:
                    </div>
                    {% if image.repo and image.ref %}
                    <div class='col-md-8'>
                        <a href="{{ image.repo }}/tree/{{ image.ref }}" target="_blank">{{ image.ref }}</a>
                    </div>
                    {% else %}
                    <div class='col-md-8'>
                        -
                    </div>
                    {%- endif %}
                </div>
            </div>
        </label>
        {% endfor %}
        </div>
        """,
        config=True,
        help="""
        Jinja2 template for constructing the list of images shown to the user.
        """,
    )

    notebook_dir = Unicode(
        '/home/{username}/{coursedir}',
        **Spawner.notebook_dir.metadata
    )

    workdir = Unicode(
        '/home/{username}/{coursedir}',
        **CoursewareUserSpawner.workdir.metadata
    )

    admin_home_mount_dirs = List(
        trait=Tuple(Unicode(), Unicode()),
        default_value=[
            ('{coursedir}/admin_tools', 'admin_tools')
        ],
        **CoursewareUserSpawner.admin_home_mount_dirs.metadata
    )

    non_admin_home_mount_dirs = List(
        trait=Tuple(Unicode(), Unicode()),
        default_value=[
            ('{coursedir}/tools', 'tools'),
            ('{coursedir}/textbook', 'textbook/{coursedir}'),
            ('{coursedir}/info', 'info/{coursedir}')
        ],
        **CoursewareUserSpawner.non_admin_home_mount_dirs.metadata
    )

    def __init__(self, *args, **kwargs):
        self._course_image = None

        super().__init__(*args, **kwargs)

        self._registry = get_registry(config=self.config)

    @property
    def course_dir(self):
        course_dir = self.name
        course_dir = re.sub(r'[^\w\-_\.\(\)\+\[\]\{\}@]', '_', course_dir)
        return course_dir

    @property
    def course_image(self):
        return self._course_image

    @course_image.setter
    def course_image(self, value):
        self._course_image = value

    def template_namespace(self):
        d = super().template_namespace()

        d.update(dict(
            coursedir=self.course_dir
        ))
        return d

    async def get_options_form(self):
        """
        Override the default form to handle the case when there is only one image.
        """
        images = await self._registry.list_images()
        image_dict = {i['image_name']: i for i in images}

        if not self.user.admin:
            if self.course_image and self.course_image in image_dict:
                self.image = self._registry.get_full_image_name(self.course_image)
            else:
                self._use_default_course_image(images)
            return ''

        if len(images) <= 1:
            self._use_initial_course_image(images)
            return ''

        for i in images:
            if self.course_image and self.course_image in image_dict:
                i['selected'] = (i['image_name'] == self.course_image)
            else:
                i['selected'] = i['default_course_image']

        image_form_template = Environment(loader=BaseLoader).from_string(
            self.image_form_template
        )
        return image_form_template.render(image_list=images, registry_host=self._registry.host)

    async def check_allowed(self, image):
        images = await self._registry.list_images()

        registry_host = self._registry.host
        image_names = [
            f'{registry_host}/{image["image_name"]}'
            for image in images
        ]

        if image not in image_names:
            raise web.HTTPError(400, "Specifying image to launch is not allowed")
        return image

    def _use_default_course_image(self, images):
        self.image = self._registry.get_default_course_image()

        default_course_images = [i for i in images if i['default_course_image']]
        if not default_course_images:
            self._use_initial_course_image(images)
            return

    def _use_initial_course_image(self, images):

        self.image = self._registry.get_initial_course_image()

        initial_course_images = [i for i in images if i['initial_course_image']]
        if not initial_course_images:
            raise RuntimeError("Initial course image NOT found")

    async def _get_cmd_from_image(self):
        parts = self.image.split('/', 1)
        if len(parts) == 2:
            host, image_name = parts
        else:
            host, image_name = ('', parts[0])

        if host == self._registry.host:
            name, ref = split_image_name(image_name)
            config = await self._registry.inspect_image(name, ref)
            cmd = config['data']['config']['Cmd']
        else:
            image_info = await self.docker("inspect_image", self.image)
            cmd = image_info["Config"]["Cmd"]
        return cmd

    async def get_command(self):
        image_cmd = await self._get_cmd_from_image()
        # override cmd for docker-stacks image
        if (image_cmd == ['start-notebook.sh']
                or image_cmd == ['start-notebook.py']):
            return image_cmd + self.get_args()

        if self.cmd:
            cmd = self.cmd
        else:
            cmd = image_cmd

        return cmd + self.get_args()

    def get_env(self):
        env = super().get_env()
        env.update(dict(
            CWH_COURSE_NAME=self.course_dir
        ))
        return env

    def _make_user_dirs(self):
        if self.course_dir:
            return

        home_dir = os.path.join(self.users_dir, self.user.name)
        dirs = []
        if self.user.admin:
            dirs.extend([
                (os.path.join(home_dir, 'textbook'), 0o777),
                (os.path.join(home_dir, 'info'), 0o777)
            ])

        statinfo = os.stat(home_dir)
        for dirpath, mode in dirs:
            self._make_dir(dirpath, mode, statinfo.st_uid, statinfo.st_gid)

    def _make_user_course_dirs(self):
        if not self.course_dir:
            return

        content_dirs = [
            os.path.join(self.admin_data_dir, 'textbook', self.course_dir),
            os.path.join(self.admin_data_dir, 'info', self.course_dir)
        ]

        home_dir = os.path.join(self.users_dir, self.user.name)
        course_dirs = [
            (os.path.join(home_dir, self.course_dir), 0o755)
        ]

        if self.user.admin:
            course_dirs.extend([
                (os.path.join(home_dir, self.course_dir, 'textbook'), 0o777),
                (os.path.join(home_dir, self.course_dir, 'info'), 0o777)
            ])

            for dirpath in content_dirs:
                self._make_dir(dirpath, 0o777, 0, 0)
        else:
            if any([not os.path.exists(d) for d in content_dirs]):
                raise web.HTTPError(
                    403,
                    'You are not permitted to create a new course, "%s".',
                    self.course_dir)

        statinfo = os.stat(home_dir)
        for dirpath, mode in course_dirs:
            self._make_dir(dirpath, mode, statinfo.st_uid, statinfo.st_gid)

    def _make_dir(self, dirpath, mode, uid, gid):
        try:
            os.mkdir(dirpath, mode)
        except FileExistsError:
            os.chmod(dirpath, mode)
        os.chown(dirpath, uid, gid)

    async def create_object(self, *args, **kwargs):
        server_name = self.name
        course_dir = self.course_dir
        notebook_dir = self.format_string(self.notebook_dir)
        workdir = self.format_string(self.workdir)
        self.log.debug(
                f"create_object: server_name='{server_name}'"
                f" course_dir='{course_dir}'"
                f" notebook_dir={notebook_dir}"
                f" workdir={workdir}"
                f" image='{self.image}'")

        self._make_user_dirs()
        self._make_user_course_dirs()

        self.docker(
            'login',
            username=self._registry.username,
            password=self._registry.password,
            registry=self._registry.get_registry_url())
        return await super().create_object(*args, **kwargs)


def cwh_repo2docker_jupyterhub_config(
        c,
        config_file=None,
        service_name='environments',
        custom_menu=False,
        service_environments={},
        debug=False):
    # hub
    c.JupyterHub.spawner_class = Repo2DockerSpawner

    c.DockerSpawner.cmd = ["jupyterhub-singleuser"]

    if custom_menu:
        # add extra templates for the service UI
        c.JupyterHub.template_paths.insert(
            0, os.path.join(os.path.dirname(__file__), "custom_templates")
        )

    service_command = [
        sys.executable,
        "-m", "cwh_repo2docker.service",
    ]

    if config_file is not None:
        service_command.extend([
            "--config-file", config_file
        ])

    if debug:
        service_command.extend([
            "--debug"
        ])

    c.JupyterHub.template_vars.update({
        'cwh_repo2docker_service_name': service_name
    })

    c.JupyterHub.services.extend([{
        "name": service_name,
        "command": service_command,
        "url": "http://127.0.0.1:10101",
        "display": not custom_menu,
        "oauth_no_confirm": True,
        "environment": service_environments,
        "oauth_client_allowed_scopes": ["inherit"]
    }])
