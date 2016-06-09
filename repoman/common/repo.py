#!/usr/bin/env python
# encoding:utf-8
"""
This module holds the class and methods to manage a repository.

In our case a repository is not just a yum repository but a set of them and
another files, in the following structure::

    repository_dir
    ├── store1_dir
    │   └── ...
    └── store2_dir
        └── ...
"""
import logging
import os
import shutil
import sys
from functools import wraps

import tempfile
import atexit

from . import utils
from .parser import Parser
from .stores import STORES


logger = logging.getLogger(__name__)


def cleanup(temp_dir):
    if os.path.isdir(temp_dir):
        shutil.rmtree(temp_dir)
        logger.info('Cleaning up temporary dir %s', temp_dir)


def loaded(func):
    @wraps(func)
    def _func(self, *args, **kwargs):
        self.load()
        return func(self, *args, **kwargs)

    return _func


class Repo(object):
    """
    Represents the repository sctructure, it does not require that the repo has
    the structure specified in the module doc when loading it, but when adding
    new rpms or generating the sources it will create the new files in that
    directory structure.

    Configuration options:

    * allowed_repo_paths
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
        self.added_artifacts = []
        self.loaded = False
        self.parser = None
        logger.debug(config)
        for allowed_path in self.config.getarray('allowed_repo_paths'):
            if self.path.startswith(allowed_path):
                break
        else:
            if self.config.getarray('allowed_repo_paths'):
                raise Exception("Repo path outside allowed paths %s"
                                % self.path)
        self.stores = config.getarray('stores')
        temp_dir = self.config.get('temp_dir')
        if temp_dir == 'generate':
            temp_dir = tempfile.mkdtemp()
            atexit.register(cleanup, temp_dir)
            self.config.set('temp_dir', temp_dir)

    def load(self):
        """
        Actually load all the stores and load the contents of the repo
        """
        if self.loaded:
            return

        logger.debug('Loading repo %s', self.path)
        self.stores = dict([
            (
                key,
                val(
                    config=self.config.get_section('store.' + key),
                    repo_path=self.path
                )
            )
            for (key, val) in STORES.iteritems()
            if key in self.stores or 'all' in self.stores
        ])
        self.config.set('stores', ', '.join(self.stores.keys()))
        self.parser = Parser(
            config=self.config,
            stores=self.stores,
        )
        self.loaded = True

    def add_source(self, artifact_source):
        """
        Generic function to add an artifact to the repo.

        Some base (meta-)sources are supported, like:

        * `conf:path/to/file`: This will include all the sources defined in
            the file `path/to/file`, it supports shell comments in the file,
            and empty lines

        * `stdin`: This will read any sources passd through stdin, with the
            same format as conf: files (`cat sources | repoman myrepo add
            stdin` is the same as `repoman myrepo add conf:sources`)

        * `repo-suffix:suffix_string`: This allows you to define a suffix
            string for the destination repo, it's helpful to allow generating
            custom repos from a base one, when the repoman command is hardcoded
            (with the combination of stdin source)

        * `repo-extra-dir:dirname`: This allows you to define an extra subdir
            string for the destination repo, it's helpful to allow generating
            custom repos from a base one, when the repoman command is hardcoded
            (with the combination of stdin source).

        :param artifact_source: source string of the artifact to add
        """
        # Handle the special case of a config file, a metasource (source of
        # sources)
        if artifact_source.startswith("conf:"):
            conf_path = artifact_source.split(':', 1)[1]
            if conf_path == 'stdin':
                self.parse_source_stream(sys.stdin.readlines())
                return

            with open(artifact_source.split(':', 1)[1]) as conf_file_fd:
                self.parse_source_stream(conf_file_fd)

            return

        elif artifact_source.startswith("repo-suffix:"):
            repo_suffix = artifact_source.split(':', 1)[-1]
            logger.info('Adding repo suffix %s', repo_suffix)
            self.add_path_suffix(suffix=repo_suffix)
            return

        elif artifact_source.startswith("repo-extra-dir:"):
            repo_extra_dir = artifact_source.split(':', 1)[-1]
            logger.info('Adding repo extra dir %s', repo_extra_dir)
            self.add_path_extra_dir(dirname=repo_extra_dir)
            return

        self.load()
        logger.info('Resolving artifact source %s', artifact_source)
        artifact_paths = self.parser.parse(artifact_source)
        for artifact_path in artifact_paths:
            for store in self.stores.itervalues():
                if store.handles_artifact(artifact_path):
                    store.add_artifact(artifact_path)
                    self.added_artifacts.append(artifact_path)

    def parse_source_stream(self, source_stream):
        """
        Given a iterable of sources, add all that apply, skipping comments and
        empty lines

        :param source_stream: iterable with the sources, can be an open file
            object as returned by `open`
        """
        for line in source_stream:
            if not line.strip() or line.strip().startswith('#'):
                continue
            self.add_source(line.strip())

    @loaded
    def save(self):
        """
        Realize all the changes made so far
        """
        for store in self.stores.itervalues():
            store.save()

    @loaded
    def delete_old(self, num_to_keep=1, noop=False):
        """
        Remove any old versions but the latest `num_to_keep`

        :param num_to_keep: Number of versions to keef for each artifact
        :param noop: if True will not actually remove anything
        """
        if not num_to_keep:
            return
        removed = []
        for store in self.stores.itervalues():
            for artifact in store.get_all_but_latest(num=num_to_keep):
                removed.append(artifact)
                if not noop:
                    store.delete_version(
                        art_name=artifact.name,
                        art_version=artifact.version,
                    )
        return removed

    def add_path_suffix(self, suffix):
        """
        Adds a suffix to the repo's path

        Args:
            suffix (str): Suffix to postpend to the repo's path

        Returns:
            None
        """
        clean_suffix = utils.sanitize_file_name(suffix)
        for store in self.stores.values():
            store.change_path(store.path + clean_suffix)
        self.path += clean_suffix

    def add_path_extra_dir(self, dirname):
        """
        Adds an extra subdir to the curret path

        Args:
            dirname (str): Name of the extra dir to add

        Returns:
            None
        """
        clean_dirname = utils.sanitize_file_name(dirname)
        self.rebase(new_path=os.path.join(self.path, clean_dirname))

    def rebase(self, new_path):
        """
        Changes the root path of the repo

        Args:
            new_path (str): New path to root the repo to

        Returns:
            None
        """
        logger.debug('Rebasing repo %s to %s', self.path, new_path)
        previously_added_artifacts = self.added_artifacts
        self.__init__(path=new_path, config=self.config)
        self.added_artifacts = previously_added_artifacts
        if self.added_artifacts:
            self.load()

        for added_artifact in self.added_artifacts:
            for store in self.stores.itervalues():
                if store.handles_artifact(added_artifact):
                    logger.debug('Readding artifact %s', added_artifact)
                    store.add_artifact(added_artifact)
