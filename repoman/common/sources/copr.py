#!/usr/bin/env python
"""
Usage::

    https?://${copr_host}/*

Handles copr build urls
"""
import logging
import re


import requests


from . import ArtifactSource
from .url import URLSource
from ..utils import split


logger = logging.getLogger(__name__)


class CoprURLSource(ArtifactSource):
    __doc__ = __doc__

    DEFAULT_CONFIG = {
        'copr_host_re': r'copr\.fedorainfracloud\.org',
    }
    CONFIG_SECTION = 'CoprURLSource'

    @classmethod
    def formats_list(cls):
        return (
            "https://{CoprURLSource[copr_host_re]}/*",
        )

    def expand(self, source_str):
        art_list = []
        if not re.match('https://%s/' % self.config.get('copr_host_re'),
                        source_str):
            return '', art_list
        # remove filters
        _, url = source_str.split('://', 1)
        url, filters_str = split(url, ':', 1)
        lvl1_url = 'https://%s' % url

        lvl1_page = requests.get(lvl1_url).text
        lvl2_reg = re.compile(r'(?<=href=")[^"]+/results/[^"]+(?=")')
        logger.info('Parsing Copr URL: %s', lvl1_url)
        lvl2_urls = [
            URLSource.get_link(lvl1_url, match.group())
            for match in (lvl2_reg.search(i) for i in lvl1_page.splitlines())
            if match
        ]
        for url in lvl2_urls:
            logger.info('    Got 2nd level URL: %s', url)
            art_list.extend(
                URLSource(
                    config=self.config,
                    stores=self.stores
                ).expand_page(url)
            )
        if not art_list:
            logger.warn('    No packages found')
            logger.info('    Done')
        return filters_str, art_list
