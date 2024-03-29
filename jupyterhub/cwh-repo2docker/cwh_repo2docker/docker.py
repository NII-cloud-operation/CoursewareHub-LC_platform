import json

from urllib.parse import urlparse

from aiodocker import Docker


async def list_containers():
    """
    Retrieve the list of local images being built by repo2docker.
    Images are built in a Docker container.
    """
    async with Docker() as docker:
        r2d_containers = await docker.containers.list(
            filters=json.dumps({"label": ["repo2docker.ref"]})
        )
    containers = [
        {
            "repo": container["Labels"]["repo2docker.repo"],
            "ref": container["Labels"]["repo2docker.ref"],
            "image_name": container["Labels"]["repo2docker.build"],
            "display_name": container["Labels"]["cwh_repo2docker.display_name"],
            "status": "building",
        }
        for container in r2d_containers
        if "repo2docker.build" in container["Labels"]
    ]
    return containers


async def build_image(
    registry_host, repo, ref, name="", username=None, password=None, extra_buildargs=None
):
    """
    Build an image given a repo, ref and limits
    """
    ref = ref or "HEAD"
    if len(ref) >= 40:
        ref = ref[:7]

    # default to the repo name if no name specified
    # and sanitize the name of the docker image
    name = name or urlparse(repo).path.strip("/")
    name = name.lower().replace("/", "-")
    image_name = f"{name}:{ref}"
    image_name = image_name.lower().replace("/", "-")
    image_registry_name = f"{registry_host}/{image_name}"

    # add extra labels to set additional image properties
    labels = [
        f"cwh_repo2docker.display_name={name}",
        f"cwh_repo2docker.image_name={image_name}",
    ]
    cmd = [
        "jupyter-repo2docker",
        "--ref",
        ref,
        "--user-name",
        "jovyan",
        "--user-id",
        "1100",
        # for using docker-stacks start.sh script in buildpack-deps image
        "--appendix",
        "ENV NB_USER=${NB_USER:-jovyan} NB_UID=${NB_UID:-1100} NB_GID=${NB_GID:-1100}",
        "--no-run",
        "--push",
        "--image-name",
        image_registry_name,
    ]

    for label in labels:
        cmd += [
            "--label",
            label
        ]

    for barg in extra_buildargs or []:
        cmd += [
            "--build-arg",
            barg
        ]

    cmd.append(repo)

    config = {
        "Cmd": cmd,
        "Image": "quay.io/jupyterhub/repo2docker:main",
        "Labels": {
            "repo2docker.repo": repo,
            "repo2docker.ref": ref,
            "repo2docker.build": image_name,
            "cwh_repo2docker.display_name": name,
        },
        "Volumes": {
            "/var/run/docker.sock": {},
            "/root/.docker/config.json": {}
        },
        "HostConfig": {
            "Binds": [
                "/var/run/docker.sock:/var/run/docker.sock",
                "/root/.docker/config.json:/root/.docker/config.json:ro"
            ],
            "AutoRemove": True
        },
        "Tty": False,
        "AttachStdout": False,
        "AttachStderr": False,
        "OpenStdin": False,
    }

    if username and password:
        config.update(
            {
                "Env": [f"GIT_CREDENTIAL_ENV=username={username}\npassword={password}"],
            }
        )

    async with Docker() as docker:
        await docker.containers.run(config=config)
