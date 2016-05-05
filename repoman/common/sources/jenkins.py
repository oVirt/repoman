#!/usr/bin/env python
"""
Allows you to define a jenkins build job url as a source:

* If it's a build -> the artifacts archived on that build
* If it's a job -> the artifacts from the last successful build
* If it's a multiconfig build -> the artifacts from all the configs

For example::
    repoman myrepo add \\
        http://jenkins.ovirt.org/jobs/lago_master_build-artifacts-el7-x86_64

will get the latest successful build artifacts for that job.

Keep in mind that if the url does not match the regexp in the config, you can
still force repoman to use this source prepending the url with 'jenkins:', like
this::

    repoman myrepo add \\
        jenkins:http://some.strange.url/to/my_job

"""
import logging
import re
import time

import requests

from ..stores import has_store
from ..utils import (
    split,
    response2str,
)
from . import ArtifactSource


logger = logging.getLogger(__name__)


class JenkinsSource(ArtifactSource):
    __doc__ = __doc__

    DEFAULT_CONFIG = {
        'jenkins_host_re': r'jenkins\.ovirt\.org',
    }
    CONFIG_SECTION = 'JenkinsSource'

    @classmethod
    def formats_list(cls):
        return (
            "https?://{JenkinsSource[jenkins_host_re]/*}",
        )

    def expand(self, source_str):
        art_list = []
        if (
            has_store(source_str, self.stores)
            or not re.match(
                'https?://%s/' % self.config.get('jenkins_host_re'),
                source_str,
            ) and not source_str.startswith('jenkins:')
        ):
            return source_str, art_list

        if source_str.startswith('jenkins:'):
            source_str = source_str.split(':', 1)[1]

        filters_str = split(source_str, ':', 2)[-1]
        source_str = ':'.join(source_str.split(':', 2)[:2])
        tries = 3
        while tries >= 0:
            try:
                lvl1_page = requests.get(
                    source_str + '/api/json?depth=3'
                )
                if lvl1_page.ok:
                    lvl1_page = lvl1_page.json()
                    break
                else:
                    logger.error(response2str(lvl1_page))
            except ValueError as exc:
                logger.error(response2str(lvl1_page))
            time.sleep(2)
            tries -= 1
        else:
            logger.error(
                'Failed to download %s after %d tries',
                source_str,
                tries,
            )
            raise exc
        url = lvl1_page['url']
        logger.info('Parsing jenkins URL: %s', source_str)
        if url.endswith('/'):
            url = url[:-1]
        # handle multicongif jobs
        for run in lvl1_page.get('runs', (lvl1_page,)):
            if run.get('number', None) != lvl1_page.get('number', None):
                continue
            for artifact in run.get('artifacts', []):
                if not has_store(artifact['relativePath'], self.stores):
                    continue
                new_url = '%s/artifact/%s' % (
                    run['url'],
                    artifact['relativePath']
                )
                art_list.append(new_url)
                logger.info('    Got URL: %s', new_url)
        if not art_list:
            logging.warn('    No artifacts found')
        logging.info('    Done')
        return filters_str, art_list
