#!/usr/bin/env python
"""
Usage::

    koji:name@tag
    koji:@tag[@inherit]
    koji:name-version-release

Handles koji builds
"""
import logging

import koji

from . import ArtifactSource
from ..utils import split
from ..stores import has_store


logger = logging.getLogger(__name__)


class KojiBuildSource(ArtifactSource):

    DEFAULT_CONFIG = {
        'koji_server': 'https://koji.fedoraproject.org/kojihub',
        'koji_topurl': 'https://kojipkgs.fedoraproject.org/',
    }
    CONFIG_SECTION = 'KojiBuildSource'

    @classmethod
    def formats_list(cls):
        return (
            "koji:name@tag",
            "koji:@tag[@inherit]",
            "koji:name-version-release",
        )

    def expand(self, source_str):
        art_list = []
        if not source_str.startswith('koji:'):
            return '', art_list
        source_str = source_str.split(':', 1)[1]
        # remove filters
        source, filters_str = split(source_str, ':', 1)
        logger.info('Parsing Koji build: %s', source)
        client = koji.ClientSession(
            self.config.get('koji_server'),
            {},
        )
        topurl = self.config.get('koji_topurl')
        if source.startswith('@'):
            tag = source[1:]
            inherit = False
            if tag.endswith('@inherit'):
                inherit = True
                tag = tag.rsplit('@', 1)[0]
            builds = client.getLatestBuilds(tag=tag)
            if not inherit:
                builds = [
                    build
                    for build in builds
                    if build['tag_name'] == tag
                ]
        elif '@' in source:
            name, tag = source.split('@', 1)
            builds = client.getLatestBuilds(
                tag=tag,
                package=name,
            )
        else:
            builds = [client.getBuild(source)]
        logging.info('    Got %d builds' % len(builds))
        for build in builds:
            if not build:
                continue
            if 'build_id' in build:
                build_id = build.get('build_id')
            else:
                build_id = build.get('id')
            pathinfo = koji.PathInfo(topdir=topurl)
            rpms = client.listRPMs(buildID=build_id)
            if not rpms:
                logger.warn('        No rpms for build %d', build_id)
            else:
                logger.info(
                    '        Got %d rpms for build %d' % (len(rpms), build_id),
                )
            for rpm in rpms:
                url = pathinfo.build(build) + '/' + pathinfo.rpm(rpm)
                if has_store(url, self.stores):
                    art_list.append(url)
        if not art_list:
            logger.warn('    No packages found')
            logger.info('    Done')
        return filters_str, art_list
