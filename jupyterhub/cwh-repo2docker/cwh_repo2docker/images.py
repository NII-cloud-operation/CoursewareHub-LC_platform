from jupyterhub.services.auth import HubOAuthenticated
from tornado import web

from .docker import list_containers
from .registry import get_registry
from .base import BaseHandler


class ImagesHandler(HubOAuthenticated, BaseHandler):
    """
    Handler to show the list of environments as Docker images
    """

    @web.authenticated
    async def get(self):
        registry = get_registry(config=self.settings['config'])
        images = await registry.list_images()
        containers = await list_containers()
        result = self.render_template(
            "images.html",
            images=images + containers
        )
        self.write(await result)
