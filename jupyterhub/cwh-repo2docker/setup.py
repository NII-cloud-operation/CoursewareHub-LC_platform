#!/usr/bin/env python
# coding: utf-8

from setuptools import setup, find_packages

setup_args = dict(
    name                 = 'cwh-repo2docker',
    version              = '0.1.0',
    platforms            = "Linux",
    packages             = find_packages(),
    include_package_data = True,
    install_requires     = [
        "coursewareuserspawner",
        "jupyterhub~=3.1",
        "aiodocker",
        'aiohttp']
)


def main():
    setup(**setup_args)

if __name__ == '__main__':
    main()
