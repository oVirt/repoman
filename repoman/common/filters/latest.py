#!/usr/bin/env python
"""
Usage::

    source:latest
    source:latest=N

Get's the latest N rpms (1 by default)
"""
import re
import logging

from . import ArtifactFilter
from ..utils import split


logger = logging.getLogger(__name__)  # pylint: noqa


class LatestFilter(ArtifactFilter):
    __doc__ = __doc__

    DEFAULT_CONFIG = {}
    CONFIG_SECTION = 'LatestFilter'

    def filter(self, filters_str, art_list):
        match = re.match(r'latest(=(?P<num>\d+))?(:.*)?$', filters_str)
        if not match or not art_list:
            return filters_str, art_list
        filters_str = split(filters_str, ':', 1)[-1]
        latest = match.groupdict().get('num', 1) or 1
        stores = [store.get_empty_copy() for store in self.stores]
        # populate the stores with the artifacts
        for artifact in art_list:
            for store in stores:
                if store.handles_artifact(artifact):
                    store.add_artifact(artifact)
                    # only add it to the first matching store
                    break
        # gather the latest artifacts from each store
        filtered_arts = set()
        for store in stores:
            filtered_arts = filtered_arts.union(
                art.path for art in store.get_latest(num=int(latest))
            )
        for artifact in filtered_arts:
            logger.debug("Passed the filter: %s", artifact)
        return (filters_str, filtered_arts)
