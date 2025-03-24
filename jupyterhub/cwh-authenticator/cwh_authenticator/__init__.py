from jupyterhub.handlers import LogoutHandler
from jhub_remote_user_authenticator.remote_user_auth import RemoteUserLocalAuthenticator
from jhub_remote_user_authenticator.remote_user_auth import RemoteUserLoginHandler


class CoursewareHubLoginHandler(RemoteUserLoginHandler):

    def get(self):
        course_server = self.get_query_argument('course_server', None)
        course_image = self.get_query_argument('course_image', None)

        super().get()

        user = self.current_user
        self.log.debug("course_server: %s, user=%s", course_server, user.name)
        self.log.debug("course_image: %s, user=%s", course_image, user.name)

        if course_server:
            spawner = user.get_spawner(course_server, replace_failed=True)
            spawner.course_image = course_image


class CoursewareHubLogoutHandler(LogoutHandler):

    async def render_logout_page(self):
        self.redirect('/php/logout.php', permanent=False)


class CoursewareHubRemoteUserLocalAuthenticator(RemoteUserLocalAuthenticator):

    def get_handlers(self, app):
        return [
            (r'/login', CoursewareHubLoginHandler),
            (r'/logout', CoursewareHubLogoutHandler)
        ]

