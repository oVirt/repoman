#!/usr/bin/env python
"""
When specifying a source for an artifact, you have to do it in this format:

source_type:value[:filter[:filter[...]]]

For each source, it will be expanded, and filtered. An example:

repo:master-nightly:name~ovirt-engine.*:latest=2

"""
import logging
from . import (
    sources,
    filters,
)


logger = logging.getLogger(__name__)


class Parser(object):
    def __init__(self, config, stores):
        """
        :param config: configuration for the parser
        :param stores: instances of the available stores
        """
        self.config = config
        self.stores = stores
        self.filters = config.getarray('filters')
        self.filters = dict([
            (
                cname,
                cls(
                    stores=stores.values(),
                    config=config.get_section(
                        section='filter.' + cls.CONFIG_SECTION,
                    )
                )
            )
            for cname, cls in filters.FILTERS.iteritems()
            if cname in self.filters or 'all' in self.filters
        ])
        self.sources = config.getarray('sources')
        self.sources = dict([
            (
                cname,
                cls(
                    stores=stores.values(),
                    config=config.get_section(
                        section='source.' + cls.CONFIG_SECTION,
                    )
                )
            )
            for cname, cls in sources.SOURCES.iteritems()
            if cname in self.sources or 'all' in self.sources
        ])

    def parse(self, full_source_str):
        """
        Parses the given source sting and returns a list of resolved artifact
        paths

        :param full_source_str: Source sting to parse
        :type full_source_str: Sting
        :rtype: list of strings
        """
        art_list = set()
        for stuple in self.sources.iteritems():
            aname = stuple[0]
            source = stuple[1]
            source_str = full_source_str
            logger.debug('Checking source %s with %s', aname, source_str)
            result = source.expand(source_str)
            filters_str = result[0]
            art_list = result[1]
            if not art_list:
                # if no artifacts for this source type, try next
                continue
            # check if there were any filters in the source definition, finish
            # if not
            if not filters_str:
                break
            # check all the filters until finished or we can't resolve any more
            # of the filters strings
            prev_filters_str = ''
            while filters_str and filters_str != prev_filters_str:
                prev_filters_str = filters_str
                for fname, fclass in self.filters.iteritems():
                    logger.info('Filtering filter %s with %s',
                                filters_str, fname)
                    result = fclass.filter(
                        filters_str,
                        art_list,
                    )
                    filters_str, art_list = result
                if not filters_str:
                    break
            # We skip all other sources if we found the matching one
            break
        if not art_list:
            msg = 'No artifacts found for source %s' % source_str
            logger.error(msg)
            raise Exception(msg)
        logging.debug(
            'From source string %s got: %s',
            full_source_str,
            art_list
        )
        return art_list
