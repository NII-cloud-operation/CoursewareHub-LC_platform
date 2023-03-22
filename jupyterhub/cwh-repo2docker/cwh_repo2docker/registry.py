import aiohttp
import asyncio
import json
from typing import (
    Dict,
    Optional,
    Tuple,
    List
)
from urllib.parse import urlencode
from yarl import URL

from textwrap import dedent
from traitlets import (
    Unicode,
    Bool
)
from traitlets.config import SingletonConfigurable


CONTENT_TYPE_MANIFEST_V2_2 = 'application/vnd.docker.distribution.manifest.v2+json'


def get_registry(*args, **kwargs):
    return Registry.instance(*args, **kwargs)


async def _get_manifest(
        session: aiohttp.ClientSession,
        url: str,
        name: str,
        ref: str) -> Optional[Dict]:
    headers = {
        'Accept': CONTENT_TYPE_MANIFEST_V2_2
    }
    async with session.get(
            f'{url}{name}/manifests/{ref}',
            headers=headers) as resp:
        manifest = await resp.json()
        if resp.status == 404:
            return None
        return {
            'name': name,
            'reference': ref,
            'digest': resp.headers.get('Docker-Content-Digest'),
            'data': manifest
        }


async def _put_manifest(
        session: aiohttp.ClientSession,
        url: str,
        name: str,
        ref: str,
        manifest: Dict) -> Dict:
    headers = {
        'Content-Type': CONTENT_TYPE_MANIFEST_V2_2
    }
    async with session.put(
            f'{url}{name}/manifests/{ref}',
            json=manifest,
            headers=headers) as resp:
        await resp.read()
        return {
            'name': name,
            'reference': ref,
            'digest': resp.headers.get('Docker-Content-Digest')
        }


async def _delete_manifest(
        session: aiohttp.ClientSession,
        url: str,
        name: str,
        manifest_digest: str) -> None:
    async with session.delete(
            f'{url}{name}/manifests/{manifest_digest}') as resp:
        await resp.read()


async def _get_tags(
        session: aiohttp.ClientSession,
        url: str,
        repo: str) -> None:
    async with session.get(f'{url}{repo}/tags/list') as resp:
        return await resp.json()


async def _get_repos(
        session: aiohttp.ClientSession,
        url: str) -> Dict:
    async with session.get(f'{url}_catalog') as resp:
        return await resp.json()


async def _get_config(
        session: aiohttp.ClientSession,
        url: str,
        repo: str,
        ref: str,
        manifest: Dict) -> Dict:
    config_digest = manifest['data']['config']['digest']
    config_blob = await _get_blob(
        session, url, repo, config_digest)
    config = json.loads(config_blob)
    return {
        'name': repo,
        'reference': ref,
        'manifest': manifest,
        'data': config,
        'digest': config_digest
    }


async def _get_blob(
        session: aiohttp.ClientSession,
        url: str,
        repo: str,
        digest: str) -> bytes:
    async with session.get(
            f'{url}{repo}/blobs/{digest}') as resp:
        return await resp.read()


async def _delete_blob(
        session: aiohttp.ClientSession,
        url: str,
        repo: str,
        digest: str) -> None:
    async with session.delete(f'{url}{repo}/blobs/{digest}') as resp:
        await resp.read()


async def _head_blob(
        session: aiohttp.ClientSession,
        url: str,
        repo: str,
        digest: str) -> Optional[Tuple[str, str]]:
    async with session.head(f'{url}{repo}/blobs/{digest}',
                            raise_for_status=False) as resp:
        await resp.read()
        if resp.status == 200:
            return (
                resp.headers['Content-Length'],
                resp.headers['Docker-Content-Digest']
            )
        if resp.status == 404:
            return None
        resp.raise_for_status()
        return None


def split_image_name(
        image_name: str,
        default_tag: str = 'latest') -> Tuple[str, str]:
    parts = image_name.rsplit(':', 1)
    if len(parts) == 2:
        name, tag = parts
    else:
        name, tag = (parts[0], default_tag)
    return (name, tag)


def _short_id(id: str) -> str:
    sep = id.find(':')
    return id[sep+1:sep+13]


class Registry(SingletonConfigurable):
    """
    Docker registry client to manage course images.
    """

    host = Unicode(
        config=True,
        allow_none=False,
        help=dedent(
            """
            Host name of registry server.
            e.g. `localhost:5000`
            """
        )
    )

    username = Unicode(
        config=True,
        allow_none=False,
        help=dedent(
            """
            Username of registry
            """
        )
    )

    password = Unicode(
        config=True,
        allow_none=False,
        help=dedent(
            """
            Password of registry
            """
        )
    )

    insecure = Bool(
        False,
        config=True,
        help=dedent(
            """
            Use HTTP instead of HTTPS.
            Default is False.
            """
        )
    )

    default_course_image = Unicode(
        'coursewarehub/default-course-image:latest',
        config=True,
        help="""
        Name of default course image, excluding registry host name
        """
    )

    initial_course_image = Unicode(
        'coursewarehub/initial-course-image:latest',
        config=True,
        help="""
        Name of initial course image, excluding registry host name
        """
    )

    def __init__(self, *args, **kwargs):
        super(Registry, self).__init__(*args, **kwargs)

        self.log.debug('Registry host: %s', self.host)
        self.log.debug('Registry user: %s', self.username)
        self.log.debug('default_course_image: %s',
                       self.default_course_image)
        self.log.debug('initial_course_image: %s',
                       self.initial_course_image)

    def get_registry_url(self) -> str:
        scheme = 'https' if not self.insecure else 'http'
        return f'{scheme}://{self.host}/v2/'

    def _get_auth(self):
        return aiohttp.BasicAuth(self.username, self.password)

    def get_default_course_image(self) -> str:
        host = self.host
        name = self.default_course_image
        return f'{host}/{name}'

    def get_initial_course_image(self) -> str:
        host = self.host
        name = self.initial_course_image
        return f'{host}/{name}'

    async def list_images(self) -> List[Dict]:
        async with aiohttp.ClientSession(
                auth=self._get_auth(),
                raise_for_status=True) as session:
            url = self.get_registry_url()
            self.log.debug('registry host=%s, registry url=%s', self.host, url)

            repos = await self._list_image_names(session)
            manifests = await self._list_manifests(session, repos)

            tasks = []
            for manifest in manifests:
                name = manifest['name']
                ref = manifest['reference']
                tasks.append(asyncio.ensure_future(
                    _get_config(session, url, name, ref, manifest)))
            configs = await asyncio.gather(*tasks)

            self.log.debug('found images: %s',
                           [f"{c['name']}:{c['reference']}" for c in configs])

            default_course_image = None
            initial_course_image = None
            images = []
            for config in configs:
                labels = config['data'].get('config', {}).get('Labels', {})
                name = config['name']
                ref = config['reference']
                image_name_ref = f'{name}:{ref}'
                if self.default_course_image == image_name_ref:
                    self.log.debug(
                        'found default course image: %s labels=%s, digest=%s',
                        image_name_ref, labels, config['digest'])
                    default_course_image = config['digest']
                elif self.initial_course_image == image_name_ref:
                    self.log.debug(
                        'found initial course image: %s labels=%s digest=%s',
                        image_name_ref, labels, config['digest'])
                    initial_course_image = {
                        "repo": None,
                        "ref": None,
                        "image_name": image_name_ref,
                        "display_name": 'initial',
                        "image_id": config['digest'],
                        "short_image_id": _short_id(config['digest']),
                        "manifest_digest": config['manifest']['digest'],
                        "status": "-",
                        "config": config["data"],
                        "default_course_image": False,
                        "initial_course_image": True,
                    }
                elif ('cwh_repo2docker.image_name' in labels and
                        image_name_ref == labels['cwh_repo2docker.image_name']):
                    self.log.debug(
                        'found repo2docker course image: %s labels=%s digest=%s',
                        image_name_ref, labels, config['digest'])
                    images.append({
                        "repo": labels["repo2docker.repo"],
                        "ref": labels["repo2docker.ref"],
                        "image_name": labels["cwh_repo2docker.image_name"],
                        "display_name": labels["cwh_repo2docker.display_name"],
                        "image_id": config['digest'],
                        "short_image_id": _short_id(config['digest']),
                        "manifest_digest": config['manifest']['digest'],
                        "status": "built",
                        "config": config["data"],
                        "default_course_image": False,
                        "initial_course_image": False,
                    })
                else:
                    self.log.debug('not course image: %s labels=%s digest=%s',
                                   image_name_ref, labels, config['digest'])

            if initial_course_image:
                images.append(initial_course_image)

            if default_course_image:
                for image in images:
                    if image['image_id'] == default_course_image:
                        image['default_course_image'] = True

            return images

    async def inspect_image(self, name: str, ref: str) -> Optional[Dict]:
        async with aiohttp.ClientSession(
                auth=self._get_auth(),
                raise_for_status=True) as session:
            url = self.get_registry_url()

            manifest = await _get_manifest(session, url, name, ref)
            if manifest is None:
                return None

            return await _get_config(session, url, name, ref, manifest)

    async def delete_image(self, name: str, ref: str) -> None:
        async with aiohttp.ClientSession(
                auth=self._get_auth(),
                raise_for_status=True) as session:
            url = self.get_registry_url()

            manifest = await _get_manifest(session, url, name, ref)
            if manifest is None:
                # image not found
                return
            config = await _get_config(session, url, name, ref, manifest)
            manifest_digest = manifest['digest']

            repos = await self._list_image_names(session)
            repos = [r for r in repos if r[0] != name and r[1] != ref]
            marked_layers = await self._mark_blobs(session, repos)

            await _delete_manifest(session, url, name, manifest_digest)

            tasks = []
            tasks.append(asyncio.ensure_future(
                _delete_blob(session, url, name, config['digest'])))

            layers = manifest['data']['layers']
            for layer in layers:
                if (layer['digest'] not in marked_layers):
                    tasks.append(asyncio.ensure_future(
                        _delete_blob(session, url, name, layer['digest'])))

            await asyncio.gather(*tasks)

    async def _list_image_names(
            self,
            session: aiohttp.ClientSession) -> List[Tuple[str, str]]:
        url = self.get_registry_url()
        repos_dict = await _get_repos(session, url)
        repo_names = repos_dict['repositories']

        tasks = []
        for name in repo_names:
            tasks.append(asyncio.ensure_future(_get_tags(session, url, name)))

        taginfos = await asyncio.gather(*tasks)
        repos = []
        for taginfo in taginfos:
            name = taginfo['name']
            tags = taginfo.get('tags')
            if tags is None:
                continue
            for tag in tags:
                repos.append((name, tag))
        return repos

    async def _list_manifests(
            self,
            session: aiohttp.ClientSession,
            repos: List[Tuple[str, str]]):
        tasks = []
        url = self.get_registry_url()
        for name, tag in repos:
            tasks.append(asyncio.ensure_future(
                    _get_manifest(session, url, name, tag)))
        manifests = await asyncio.gather(*tasks)
        return manifests

    async def _mark_blobs(
            self,
            session: aiohttp.ClientSession,
            images: List[Tuple[str, str]]):
        manifests = await self._list_manifests(session, images)
        digests = set()
        for manifest in manifests:
            digests.update(
                [layer['digest'] for layer in manifest['data']['layers']]
            )
        return digests

    async def set_default_course_image(self, name: str, ref: str):
        new_name, new_ref = split_image_name(self.default_course_image)
        return await self.set_name_tag(
            new_name, new_ref, name, ref)

    async def set_name_tag(
            self,
            new_name: str,
            new_tag: str,
            src_name: str,
            src_tag: str):
        async with aiohttp.ClientSession(
                auth=self._get_auth(),
                raise_for_status=True) as session:
            url = self.get_registry_url()

            manifest = await _get_manifest(session, url, src_name, src_tag)
            if manifest is None:
                raise RuntimeError(f"image not found: '{src_name}:{src_tag}'")

            tasks = []
            config_digest = manifest['data']['config']['digest']
            tasks.append(asyncio.ensure_future(self._mount_blob(
                session, url, new_name, config_digest, src_name)))
            layers = manifest['data']['layers']
            for layer in layers:
                digest = layer['digest']
                tasks.append(asyncio.ensure_future(
                    self._mount_blob(session, url, new_name, digest, src_name)))
            mounted_blobs = await asyncio.gather(*tasks)
            self.log.debug('mounted blobs: dest=%s from=%s, %s',
                           new_name, src_name, str(mounted_blobs))

            if (any([x is None for x in mounted_blobs])):
                raise RuntimeError('failed to mount blobs')

            return await _put_manifest(
                session,
                url,
                new_name, new_tag,
                manifest['data'])

    async def _mount_blob(
            self,
            session: aiohttp.ClientSession,
            url: str,
            name: str,
            digest: str,
            from_name: str):
        blob = await _head_blob(session, url, name, digest)
        if blob is not None:
            return blob

        params = urlencode({
            'mount': digest,
            'from': from_name
        })
        async with session.post(
                URL(f'{url}{name}/blobs/uploads/?{params}', encoded=True),
                skip_auto_headers={
                    'Content-Type'
                },
                allow_redirects=False) as resp:
            await resp.read()
            if resp.status != 201:
                self.log.error(
                    '_mount_blob: unexpected response: %d',
                    resp.status)

        return await _head_blob(session, url, name, digest)
