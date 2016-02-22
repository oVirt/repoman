#!/usr/bin/env python
"""
This program is a helper to repo management

Started as specific for rpm files, but was modified to be able to support
different types of artifacts
"""
import argparse
import logging
import sys
from getpass import getpass


from .common.config import Config
from .common.repo import Repo
from .common.stores import STORES
from .common.sources import SOURCES


logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose', action='store_true')
    parser.add_argument('-n', '--noop', action='store_true')
    parser.add_argument(
        '-c', '--config', action='store', default=None,
        help='Configuration file to use',
    )
    parser.add_argument(
        '-o', '--option', action='append', default=[],
        help='Extra config option as in the config file, in the form '
        'section.name=value',
    )
    parser.add_argument(
        '-t', '--temp-dir', action='store', default=None,
        help='Temporary directory to use, will generate it if not passed',
    )
    parser.add_argument(
        '-s', '--stores', required=False, default=','.join(STORES.keys()),
        help='Store classes to take into account when loading the '
        'repo. Available ones are %s' % ', '.join(STORES.keys()))
    parser.add_argument(
        'dir',
        help=(
            "Directory of the repo. If there's a source entry in the form "
            "repo-suffix:some_string, then that 'some_string' will be "
            "postpended to the repo name"
        )
    )
    parser.add_argument(
        '-k', '--key', required=False,
        help='Path to the key to use when signing, will not sign any '
        'artifacts if not passed.'
    )
    parser.add_argument(
        '--passphrase', required=False, default='ask',
        help='Passphrase to unlock the singing key'
    )
    parser.add_argument(
        '--with-sources', required=False, action='store_true',
        help='Generate the sources tree.'
    )
    repo_subparser = parser.add_subparsers(dest='repoaction')
    add_artifact = repo_subparser.add_parser('add', help='Add an artifact')
    add_artifact.add_argument(
        '-t', '--temp-dir', action='store', default=None,
        help='Temporary dir to use when downloading artifacts'
    )
    add_artifact.add_argument(
        'artifact_source', nargs='*',
        help=(
            'An artifact source to add, it can be one of: '
            'conf:path_to_file will load all the sources from that file, '
            'conf:stdin wil read the sources from stdin'
            + ', '.join(
                ', '.join(source.formats_list())
                for source in SOURCES.itervalues()
            )
        )
    )
    add_artifact.add_argument(
        '--keep-latest', required=False, type=int, metavar='NUM',
        default=0, help=(
            'If passed, will remove all the artifact versions but the latest '
            'NUM'
        )
    )

    generate_src = repo_subparser.add_parser(
        'generate-src',
        help='Populate the src dir with the tarballs from the src.rpm '
        'files in the repo'
    )
    generate_src.add_argument(
        '-p', '--with-patches', action='store_true',
        help='Include the patch files'
    )

    repo_subparser.add_parser(
        'createrepo',
        help='Run createrepo on each distro repository.'
    )

    remove_old = repo_subparser.add_parser(
        'remove-old',
        help='Remove old versions of packages.'
    )
    remove_old.add_argument(
        '-k', '--keep', type=int, default=1,
        help='Number of versions to keep'
    )

    repo_subparser.add_parser(
        'sign-rpms',
        help='Sign all the packages.'
    )

    return parser.parse_args()


def main():
    args = parse_args()

    if args.verbose:
        logging.basicConfig(
            level=logging.DEBUG,
            format=(
                '%(asctime)s::%(levelname)s::'
                '%(name)s.%(funcName)s:%(lineno)d::'
                '%(message)s'
            ),
        )
        logging.root.level = logging.DEBUG
        #  we want connectionpool debug logs
        logging.getLogger('requests').setLevel(logging.DEBUG)
        logging.debug('Enabled verbose mode')
    else:
        logging.basicConfig(
            level=logging.INFO,
            format=(
                '%(asctime)s::%(levelname)s::'
                '%(name)s::'
                '%(message)s'
            ),
        )
        logger.root.level = logging.INFO
        #  we don't want connectionpool info logs
        logging.getLogger('requests').setLevel(logging.ERROR)

    if args.config:
        config = Config(path=args.config)
    else:
        config = Config()

    # handle all the custom options
    for opt_val in args.option:
        if '=' not in opt_val:
            raise Exception('Invalid option passed %s' % opt_val)
        opt, val = opt_val.split('=')
        if '.' not in opt:
            raise Exception('Invalid option passed %s' % opt_val)
        sect, opt = opt.rsplit('.', 1)
        config.add_to_section(sect, opt, val)

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
        if args.keep_latest < 0:
            logger.error('keep-latest must be >0')
            sys.exit(1)
        logger.info('Adding artifacts to the repo %s', repo.path)
        for art_src in args.artifact_source:
            repo.add_source(art_src.strip())
        if args.keep_latest > 0:
            header_msg = 'Removed'
            if args.noop:
                header_msg = 'Would have removed'
            # save to make sure that the rpm's inodes point to the new repo
            # before removing them
            repo.save()
            for artifact in repo.delete_old(
                num_to_keep=args.keep_latest,
                noop=args.noop
            ):
                logger.info('%s %s', header_msg, artifact.path)
            sys.exit(0)
        else:
            logger.info('')
            repo.save()
            sys.exit(0)
    elif args.repoaction == 'generate-src':
        config.set('with_sources', 'true')
    elif args.repoaction == 'remove-old':
        if args.keep <= 0:
            logger.error('keep must be >0')
            sys.exit(1)
        header_msg = 'Removed'
        if args.noop:
            header_msg = 'Would have removed'
        for artifact in repo.delete_old(
            num_to_keep=args.keep,
            noop=args.noop
        ):
            logging.info('%s %s', header_msg, artifact)
    repo.save()
