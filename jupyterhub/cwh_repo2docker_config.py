import os

registry_host = os.environ['REGISTRY_HOST']
initial_image = os.environ.get('CONTAINER_IMAGE', 'coursewarehub/initial-course-image:latest')

c.Registry.initial_course_image = initial_image
c.Registry.default_course_image = os.environ.get('CONTAINER_IMAGE', 'coursewarehub/default-course-image:latest')
c.Registry.host = registry_host
c.Registry.username = os.environ.get('REGISTRY_USER', 'cwh')
c.Registry.password = os.environ['REGISTRY_PASSWORD']

