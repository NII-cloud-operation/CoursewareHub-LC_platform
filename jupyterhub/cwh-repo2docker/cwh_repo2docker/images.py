from inspect import isawaitable
from jupyterhub.handlers.base import BaseHandler
from jupyterhub.scopes import needs_scope
from tornado import web
import json

from .docker import list_containers
from .registry import get_registry


class ImagesHandler(BaseHandler):
    """
    Handler to show the list of environments as Docker images
    """

    @web.authenticated
    @needs_scope('admin-ui')
    async def get(self):
        registry = get_registry(config=self.settings['config'])
        images = await registry.list_images()
        containers = await list_containers()
        result = self.render_template(
            "images.html",
            images=images + containers
        )
        if isawaitable(result):
            self.write(await result)
        else:
            self.write(result)
