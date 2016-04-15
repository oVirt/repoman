#!/usr/bin/env python
"""
Usage::

    source:name~regexp

Filter packges by file name, for example::

    http://myhost.com/packages/:name~vdsm.*

Will match all the packages in that url that have vdsm.* as name (will not
match any previous path in the url)
"""
import re
from . import ArtifactFilter
from ..utils import split


class NameFilter(ArtifactFilter):
    __doc__ = __doc__

    DEFAULT_CONFIG = {}
    CONFIG_SECTION = 'NameFilter'

    def filter(self, filters_str, art_list):
        filtered_arts = set()
        if filters_str.startswith('name~'):
            name_reg, filters_str = split(filters_str, ':', 1)
            name_match = re.compile(name_reg.split('~', 1)[-1])
            for art in art_list:
                if name_match.match(art.rsplit('/', 1)[-1]):
                    filtered_arts.add(art)
            return filters_str, filtered_arts
        else:
            return filters_str, art_list
