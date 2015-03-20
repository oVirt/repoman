#!/usr/bin/env python
"""
This program is a helper to repo management

Started as specific for rpm files, but was modified to be able to support
different types of artifacts
"""
import argparse
import logging
from getpass import getpass

from urllib3 import connectionpool

from .common.config import Config
from .common.repo import Repo
from .common.stores import STORES
from .common.sources import SOURCES


logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose', action='store_true')
    parser.add_argument('-n', '--noop', action='store_true')
    parser.add_argument('-c', '--config', action='store', default=None,
                        help='Configuration file to use')
    parser.add_argument('-t', '--temp-dir', action='store', default=None,
                        help='Temporary directory to use, will generate it if '
                        'not passed')
    parser.add_argument(
        '-s', '--stores', required=False, default=','.join(STORES.keys()),
        help='Store classes to take into account when loading the '
        'repo. Available ones are %s' % ', '.join(STORES.keys()))
    parser.add_argument('dir', help='Directory of the repo.')
    parser.add_argument('-k', '--key', required=False,
                        help='Path to the key to use when signing, will '
                        'not sign any rpms if not passed.')
    parser.add_argument('--passphrase', required=False, default='ask',
                        help='Passphrase to unlock the singing key')
    parser.add_argument('--with-sources', required=False, action='store_true',
                        help='Generate the sources tree.')
    repo_subparser = parser.add_subparsers(dest='repoaction')
    add_rpm = repo_subparser.add_parser('add', help='Add an artifact')
    add_rpm.add_argument(
        '-t', '--temp-dir', action='store', default=None,
        help='Temporary dir to use when downloading artifacts'
    )
    add_rpm.add_argument(
        'artifact_source', nargs='+',
        help=(
            'An artifact source to add, it can be one of: ' +
            ', '.join(', '.join(source.formats_list())
                      for source in SOURCES.itervalues())
        )
    )

    generate_src = repo_subparser.add_parser(
        'generate-src',
        help='Populate the src dir with the tarballs from the src.rpm '
        'files in the repo')
    generate_src.add_argument('-p', '--with-patches', action='store_true',
                              help='Include the patch files')

    repo_subparser.add_parser(
        'createrepo',
        help='Run createrepo on each distro repository.')

    remove_old = repo_subparser.add_parser(
        'remove-old',
        help='Remove old versions of packages.')
    remove_old.add_argument('-k', '--keep', action='store',
                            default=1, help='Number of versions to '
                            'keep')

    repo_subparser.add_parser(
        'sign-rpms',
        help='Sign all the packages.')
    return parser.parse_args()


def main():
    args = parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.DEBUG)
        logging.root.level = logging.DEBUG
        #  we want connectionpool debug logs
        connectionpool.log.setLevel(logging.DEBUG)
        logging.debug('Enabled verbose mode')
    else:
        logging.basicConfig(level=logging.INFO)
        logger.root.level = logging.INFO
        #  we don't want connectionpool info logs
        connectionpool.log.setLevel(logging.WARN)

    if args.config:
        config = Config(path=args.config)
    else:
        config = Config()

    if args.dir.endswith('/'):
        path = args.dir[:-1]
    else:
        path = args.dir
    # handle the temporary dir setting
    if args.temp_dir:
        config.set('temp_dir', args.temp_dir)
    # handle the signing_key and passphrase
    if args.key:
        config.set('signing_key', args.key)
        config.set('signing_passphrase', args.passphrase)
    if args.stores:
        config.set('stores', args.stores)
    if args.with_sources:
        config.set('with_sources', 'true')
    if config.get('signing_key', '') \
       and config.get('signing_passphrase') == 'ask':
        passphrase = getpass('Enter key passphrase: ')
        config.set('signing_passphrase', passphrase)

    # The signing key must be set prior to loading the repo
    if args.repoaction == 'sign-rpms':
        if not config.get('signing_key', ''):
            config.set('signing_key', raw_input('Path to the signing key: '))
        if config.get('signing_key', '') \
           and not config.get('signing_passphrase') \
           or config.get('signing_passphrase') == 'ask':
            passphrase = getpass('Enter key passphrase: ')
            config.set('signing_passphrase', passphrase)

    repo = Repo(path=path, config=config)
    logger.info('')
    if args.repoaction == 'add':
        logger.info('Adding artifacts to the repo %s', repo.path)
        for art_src in args.artifact_source:
            repo.add_source(art_src)
        logger.info('')
    elif args.repoaction == 'generate-src':
        config.set('with_sources', 'true')
    elif args.repoaction == 'remove-old':
        repo.delete_old(keep=int(args.keep), noop=args.noop)
    repo.save()
