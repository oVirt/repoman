#!/usr/bin/env python
import logging
from abc import (
    ABCMeta,
    abstractmethod,
    abstractproperty,
)
from ..utils import get_plugins


__all__ = get_plugins(plugin_dir=__file__.rsplit('/', 1)[0])


logger = logging.getLogger(__name__)
STORES = {}


class ArtifactStore(object):
    class __metaclass__(ABCMeta):
        def __init__(cls, name, bases, attrs):
            """
            Metaclass in charge of the registering, inherits from ABCMeta
            because ArtifactStore is an abstract class too.
            """
            ABCMeta.__init__(cls, name, bases, attrs)
            # Don't register this base class
            if name != 'ArtifactStore':
                STORES[name] = cls

    def __init__(self, config):
        self.config = config
        super(ArtifactStore, self).__init__()

    @classmethod
    def get_conf_section(cls):
        return 'store.' + cls.CONFIG_SECTION

    @abstractproperty
    def DEFAULT_CONFIG(self):
        """
        Default configuration values for that store
        """
        pass

    @abstractproperty
    def CONFIG_SECTION(self):
        """
        Configuration section name for this store
        """
        pass

    @abstractmethod
    def handles_artifact(self, artifact_str):
        """
        This method must return True if the given artifact (as a path or url)
        can be handled by the implemented store

        :param artifact_str: full path or url to the artifact
        """
        pass

    @abstractmethod
    def add_artifact(self, artifact, **args):
        """
        This method adds an artifact to the store

        :param artifact: full path or url to the artifact
        """
        pass

    @abstractproperty
    def path_prefix(self):
        """
        Returns the path prefis of the store, that is, the first level after
        the root of the repo (for example, iso, exe, src or rpm)
        """
        pass

    @abstractmethod
    def save(self, **args):
        """
        Realizes the changes made to the store, usually writing the artifacts
        to disk or any other operation required to persist the store state
        """
        pass

    @abstractmethod
    def get_latest(self, num=1, **args):
        """
        Returns the latest num versions for each artifact in the store.

        :param num: number of newest versions to return
        """

    def get_empty_copy(self):
        """
        Returns an empty copy of this store
        """
        return self.__class__(self.config)

    @abstractmethod
    def get_artifacts(self, regmatch=None, fmatch=None, latest=0):
        """
        Returns the list of artifacts matching the params

        :param regmatch: Regular expression to filter the rpms path with
        :param fmatch: Filter function, must return True for packages to be
            included, or False to be excluded. The package object will be
            passed as parameter
        :param latest: number of latest versions to return (0 for all,)
        """


def has_store(artifact, stores):
    """
    Check if any of the registered stores can handle the given artifact

    :param artifact: full path or url to the artifact
    :param stores: stores to look into
    """
    return any(
        store.handles_artifact(artifact)
        for store in stores
    )

# Force the load of all the plugins
from . import *  # noqa
