#!/usr/bin/env python
# coding: utf-8

from setuptools import setup, find_packages

setup_args = dict(
    name                 = 'cwh-authenticator',
    version              = '0.1.0',
    platforms            = "Linux",
    packages             = find_packages(),
    include_package_data = False,
    install_requires     = ['jhub_remote_user_authenticator']
)


def main():
    setup(**setup_args)

if __name__ == '__main__':
    main()

