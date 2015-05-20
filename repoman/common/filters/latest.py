#!/usr/bin/env python
"""
source:latest
source:latest=N

Get's the latest N rpms (1 by default)
"""
import re
from . import ArtifactFilter
from ..utils import split


class LatestFilter(ArtifactFilter):

    DEFAULT_CONFIG = {}
    CONFIG_SECTION = 'LatestFilter'

    def filter(self, filters_str, art_list):
        match = re.match(r'latest(=(?P<num>\d+))?(:.*)?$', filters_str)
        if not match or not art_list:
            return filters_str, art_list
        filters_str = split(filters_str, ':', 1)[-1]
        latest = match.groupdict().get('num', 1) or 1
        # populate the stores with the artifacts
        for artifact in art_list:
            store_name = next(
                (
                    s_name
                    for (s_name, s_cls) in self.stores.iteritems()
                    if s_cls.handles_artifact(artifact)
                ),
                None
            )
            if store_name is not None:
                self.stores[store_name].add_artifact(artifact)
        # gather the latest artifacts from each store
        filtered_arts = set()
        for store in self.stores.itervalues():
            filtered_arts = filtered_arts.union(
                store.get_latest(num=int(latest))
            )
        return (filters_str, filtered_arts)
