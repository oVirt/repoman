#!/usr/bin/env python
"""
source:only-missing

Gets only the artifacts that are not already there, getting only the ones
that don't have already an artifact with the same name in the repo.
"""
import logging

from . import ArtifactFilter
from ..utils import split


logger = logging.getLogger(__name__)  # pylint: noqa


class OnlyMissingFilter(ArtifactFilter):

    DEFAULT_CONFIG = {}
    CONFIG_SECTION = 'OnlyMissingFilter'

    def filter(self, filters_str, art_list):
        if not filters_str.endswith('only-missing') or not art_list:
            return filters_str, art_list
        filters_str = split(filters_str, ':', 1)[-1]
        temp_stores = [store.get_empty_copy() for store in self.stores]
        # populate the stores with the artifacts
        for artifact in art_list:
            for store in temp_stores:
                if store.handles_artifact(artifact):
                    store.add_artifact(artifact)
                    # only add it to the first matching store
                    break
        # gather the latest artifacts from each store
        filtered_arts = set()
        for tmp_store in temp_stores:
            for artifact in tmp_store.get_artifacts():
                found = any(
                    store.get_artifacts(
                        fmatch=lambda x: x.name == artifact.name,
                    )
                    for store in self.stores
                )
                if not found:
                    filtered_arts.add(artifact.path)
                else:
                    logger.debug("Did not pass the filter: %s", artifact.name)
        for artifact in filtered_arts:
            logger.debug("Passed the filter: %s", artifact)
        return (filters_str, filtered_arts)
