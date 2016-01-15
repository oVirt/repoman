#!/usr/bin/env python
"""
Usage::

    dir_path
    file_path
    dir:repo_name

Will find all the matching artifacts under the specified dir or the given
file.
If relative path passed, it will be relative to the base_repos_path config
value

Configuration values:

  * allowed_dir_paths
      Comma separated list of paths or empty string.
      If set, will not allow using any path/dir/repo from outside of those
      paths.

"""
import os
import logging


from . import ArtifactSource
from ..stores import has_store
from ..utils import (
    find_recursive,
    split,
)


logger = logging.getLogger(__name__)


class DirSource(ArtifactSource):

    DEFAULT_CONFIG = {
        'allowed_dir_paths': '',
    }
    CONFIG_SECTION = 'DirSource'

    @classmethod
    def formats_list(cls):
        return (
            "dir_path",
            "file_path",
            "dir:repo_path"
        )

    @staticmethod
    def is_allowed(path, allowed_paths):
        if allowed_paths and not any(
            matched_path
            for matched_path in allowed_paths
            if path.startswith(matched_path)
        ):
            return False
        return True

    def resolve_path(self, path):
        if os.path.isabs(path) and os.path.isdir(path):
            return path

        abs_path = os.path.abspath(path)
        if os.path.isdir(abs_path):
            return abs_path

        allowed_paths = self.config.getarray('allowed_dir_paths')
        for allowed_path in allowed_paths:
            full_path = os.path.abspath(
                os.path.join(allowed_path, path)
            )
            if os.path.isdir(full_path):
                return full_path

        raise IOError('No such directory in the path: %s' % path)

    def check_if_allowed(self, path):
        allowed_paths = self.config.getarray('allowed_dir_paths')
        if not self.is_allowed(path, allowed_paths):
            error_msg = 'Source %s outside the base path' % path
            logger.error(error_msg + '\nAllowed paths: %s', allowed_paths)
            raise IOError(error_msg)

    def expand(self, source_str):
        orig_source_str = source_str
        if source_str.startswith('dir:'):
            source_str = source_str.split(':', 1)[-1]
        elif (
            not os.path.isdir(source_str)
            and has_store(source_str, self.stores)
        ):
            return '', [source_str]
        # get rid of any trailing filters
        source_path, filters_str = split(source_str, ':', 1)
        try:
            source_path = self.resolve_path(source_path)
        except IOError:
            logger.debug('Skipping %s', orig_source_str)
            return '', []
        logger.debug('Resolved path: %s', source_path)
        self.check_if_allowed(source_path)
        return (
            filters_str,
            find_recursive(source_path, lambda x: has_store(x, self.stores))
        )
