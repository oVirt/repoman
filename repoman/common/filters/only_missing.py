#!/usr/bin/env python
"""
Usage::

    source:only-missing

Gets only the artifacts that are not already there, getting only the ones
that don't have already an artifact with the same name in the repo.

It will take only the latest from the source repo if there are multiple
versions available
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
        for artifact_path in art_list:
            for store in temp_stores:
                if store.handles_artifact(artifact_path):
                    store.add_artifact(artifact_path)
                    # only add it to the first matching store
                    break
        # gather the latest artifacts from each store
        filtered_art_paths = set()
        filtered_art_names = set()
        for tmp_store in temp_stores:
            for artifact in tmp_store.get_latest(num=1):
                if artifact.name in filtered_art_names:
                    logger.debug(
                        "Did not pass the filter, already checked: %s",
                        artifact,
                    )
                    continue

                def same_name(art1):
                    return art1.name == artifact.name

                already_in_dst_store = [
                    store.get_latest(
                        fmatch=same_name,
                        num=1,
                    )
                    for store in self.stores
                ]
                if any(already_in_dst_store):
                    logger.debug(
                        (
                            "Did not pass the filter, already in the "
                            "destination: %s",
                        ),
                        artifact
                    )
                else:
                    filtered_art_paths.add(artifact.path)
                    filtered_art_names.add(artifact.name)
                    logger.debug("Passed the filter: %s", artifact)
        return (filters_str, filtered_art_paths)
