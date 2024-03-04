import json

from tornado import web
from tornado.log import app_log

from jupyterhub.utils import url_path_join


class BaseHandler(web.RequestHandler):
    @property
    def log(self):
        return self.settings.get('log', app_log)

    def render_template(self, name, **ns):
        template_ns = {}
        template_ns.update(self.template_namespace)
        template_ns["xsrf_token"] = self.xsrf_token.decode("ascii")
        template_ns.update(ns)
        template = self.settings['jinja2_env'].get_template(name)
        return template.render_async(**template_ns)

    @property
    def template_namespace(self):
        user = self.current_user
        ns = dict(
            base_url=url_path_join(
                self.settings['base_url'],
                self.settings['hub_prefix']),
            prefix=self.settings['base_url'],
            service_prefix=self.settings['service_prefix'],
            user=user,
            static_url=self.static_url,
            no_spawner_check=True
        )
        return ns

    def get_json_body(self):
        """Return the body of the request as JSON data."""
        if not self.request.body:
            return None
        body = self.request.body.strip().decode('utf-8')
        try:
            model = json.loads(body)
        except Exception:
            self.log.debug("Bad JSON: %r", body)
            self.log.error("Couldn't parse JSON", exc_info=True)
            raise web.HTTPError(400, 'Invalid JSON in body of request')
        return model
