#!/usr/bin/env python
# encoding:utf-8
"""
This module holds the class and methods to manage a repository.

In our case a repository is not just a yum repository but a set of them and
another files, in the following structure:


repository_dir
├── store1_dir
│   └── ...
└── store2_dir
    └── ...
"""
import os
import shutil
import logging
import tempfile
import atexit
from .parser import Parser
from .stores import STORES


logger = logging.getLogger(__name__)


def cleanup(temp_dir):
    if os.path.isdir(temp_dir):
        shutil.rmtree(temp_dir)
        logger.info('Cleaning up temporary dir %s', temp_dir)


class Repo(object):
    """
    Represents the repository sctructure, it does not require that the repo has
    the structure specified in the module doc when loading it, but when adding
    new rpms or generating the sources it will create the new files in that
    directory structure.

    Configuration options:

    alowed_repo_paths
      Comma separated list of paths where repositories can be found/created
    """
    def __init__(self, path, config):
        """
        :param path: Path to the base directory, if passed it will
            automatically add all the rpms under it to the repo.
        :param config: Configuration instance with the repository
            configuration.
        """
        self.path = os.path.abspath(path)
        self.config = config
        for allowed_path in self.config.getarray('allowed_repo_paths'):
            if self.path.startswith(allowed_path):
                break
        else:
            if self.config.getarray('allowed_repo_paths'):
                raise Exception("Repo path outside allowed paths %s"
                                % self.path)
        self.stores = config.getarray('stores')
        self.stores = dict([
            (
                key,
                val(config=self.config.get_section('store.' + key),
                    repo_path=self.path)
            )
            for (key, val) in STORES.iteritems()
            if key in self.stores or 'all' in self.stores
        ])
        self.config.set('stores', ', '.join(self.stores.keys()))
        self.parser = Parser(
            config=self.config,
            stores=self.stores,
        )
        temp_dir = self.config.get('temp_dir')
        if temp_dir == 'generate':
            temp_dir = tempfile.mkdtemp()
            atexit.register(cleanup, temp_dir)
            self.config.set('temp_dir', temp_dir)

    def add_source(self, artifact_source):
        """
        Generic function to add an artifact to the repo.
        :param artifact_source: source string of the artifact to add
        """
        # Handle the special case of a config file, a metasource (source of
        # sources)
        if artifact_source.startswith("conf:"):
            self.parse_conf_file(artifact_source.split(':', 1)[1])
        logger.info('Resolving artifact source %s', artifact_source)
        artifacts = self.parser.parse(artifact_source)
        for artifact in artifacts:
            for store in self.stores.itervalues():
                if store.handles_artifact(artifact):
                    store.add_artifact(artifact)

    def parse_conf_file(self, conf_file_path):
        with open(conf_file_path) as conf_file_fd:
            for line in conf_file_fd:
                if not line.strip() or line.strip().startswith('#'):
                    continue
                self.add_source(line.strip())

    def save(self):
        """
        Realize all the changes made so far
        """
        for store in self.stores.itervalues():
            store.save()
