import logging
from abc import (
    ABCMeta,
    abstractmethod,
    abstractproperty,
)


from ..utils import get_plugins


__all__ = get_plugins(plugin_dir=__file__.rsplit('/', 1)[0])


logger = logging.getLogger(__name__)
FILTERS = {}


class ArtifactFilter(object):
    class __metaclass__(ABCMeta):
        def __init__(cls, name, bases, attrs):
            type.__init__(cls, name, bases, attrs)
            # Don't register this base class
            if name != 'ArtifactFilter':
                FILTERS[name] = cls

    def __init__(self, config, stores):
        self.stores = stores
        self.config = config
        super(ArtifactFilter, self).__init__()

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
    def filter(self, filter_str, art_list):
        """
        Filters the given art_list according to filter_str and config

        :param filter_str: string with the filter or filters to apply
        :param art_list: list of expanded artifacts
        """
        pass


# Force the load of all the plugins
from . import *  # noqa
