"""
This program is a helper to repo management

Started as specific for rpm files, but was modified to be able to support
different types of artifacts
"""
import argparse
import logging
import os
import sys
import six
from six import itervalues, iteritems
from getpass import getpass

from .common.repo import Repo
from .common import (  # noqa
    config as config_mod,
    filters,
    stores,
    sources,
    repo,
)


LOGGER = logging.getLogger(__name__)


def add_generate_src_parser(parent_parser):
    generate_src = parent_parser.add_parser(
        'generate-src',
        help='Populate the src dir with the tarballs from the src.rpm '
        'files in the repo'
    )
    generate_src.add_argument(
        '-p', '--with-patches', action='store_true',
        help='Include the patch files'
    )
    return parent_parser


def add_createrepo_parser(parent_parser):
    parent_parser.add_parser(
        'createrepo',
        help='Run createrepo on each distro repository.'
    )
    return parent_parser


def add_remove_old_parser(parent_parser):
    remove_old = parent_parser.add_parser(
        'remove-old',
        help='Remove old versions of packages.'
    )
    remove_old.add_argument(
        '-k', '--keep', type=int, default=1,
        help='Number of versions to keep'
    )

    return parent_parser


def add_sign_artifacts_parser(parent_parser):
    parent_parser.add_parser(
        'sign-rpms',
        help='Sign all the artifacts.'
    )
    parent_parser.add_parser(
        'sign-artifacts',
        help='Sign all the artifacts.'
    )

    return parent_parser


def add_add_artifact_parser(parent_parser):
    add_artifact = parent_parser.add_parser('add', help='Add an artifact')
    add_artifact.add_argument(
        'artifact_source', nargs='*',
        help=(
            'An artifact source to add, it can be one of: '
            'conf:path_to_file will load all the sources from that file, '
            'conf:stdin wil read the sources from stdin'
            + ', '.join(
                ', '.join(source.formats_list())
                for source in itervalues(sources.SOURCES)
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

    return parent_parser


def add_docs_parser(parent_parser):
    docs_parser = parent_parser.add_parser(
        'docs',
        help='Show docs on sources, filters, stores or configuration',
    )
    subject_subparser = docs_parser.add_subparsers(dest='subject')
    subject_parsers = {}
    for subject in ['filters', 'sources', 'stores', 'config']:
        subject_parsers[subject] = subject_subparser.add_parser(
            subject,
            help='Show info from the %s module' % subject,
        )
        subject_parsers[subject].add_argument(
            'element',
            nargs='?',
            default=None,
            help=(
                'What to show info about %s, empty to show general info '
                'about it' % subject
            ),
        )

    return parent_parser


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            'Artifact repositories manager. The "dir" argument is always '
            ' required, so in order to see the docs, you can pass a dummy '
            '"dir", for example "repoman shrubbery docs filters"'
        )
    )
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
        help=(
            'Temporary directory to use, will generate it if not passed. '
            'Valid values are: "generate" (default), "generate-in-repo", or '
            'a path '
        ),
    )
    parser.add_argument(
        '-s', '--stores', required=False,
        default=','.join(stores.STORES),
        help=(
            'Store classes to take into account when loading the repo. '
            'Available ones are %s' % ', '.join(stores.STORES)
        )
    )
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
    parser.add_argument(
        '--create-latest-repo', action='store_true',
        help=(
            'If set, will create a repo named "latest" in the same root dir '
            'as the given repo with the latest artifacts of all the repos in '
            'that root. Useful when combined with repo-extra-dir meta-sources.'
        ),
    )
    repo_subparser = parser.add_subparsers(dest='repoaction')
    repo_subparser = add_add_artifact_parser(repo_subparser)
    repo_subparser = add_generate_src_parser(repo_subparser)
    repo_subparser = add_createrepo_parser(repo_subparser)
    repo_subparser = add_remove_old_parser(repo_subparser)
    repo_subparser = add_sign_artifacts_parser(repo_subparser)
    repo_subparser = add_docs_parser(repo_subparser)

    return parser.parse_args()


def setup_verbose_logging():
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


def setup_regular_logging():
    logging.basicConfig(
        level=logging.INFO,
        format=(
            '%(asctime)s::%(levelname)s::'
            '%(name)s::'
            '%(message)s'
        ),
    )
    LOGGER.root.level = logging.INFO
    #  we don't want connectionpool info logs
    logging.getLogger('requests').setLevel(logging.ERROR)


def handle_custom_options(args, config):
    for opt_val in args.option:
        if '=' not in opt_val:
            raise Exception('Invalid option passed %s' % opt_val)
        opt, val = opt_val.split('=')
        if '.' not in opt:
            raise Exception('Invalid option passed %s' % opt_val)
        sect, opt = opt.rsplit('.', 1)
        config.add_to_section(sect, opt, val)

    return config


def set_signing_key(config):
    if not config.get('signing_key', ''):
        config.set(
            'signing_key',
            six.moves.input('Path to the signing key: '),
        )

    if (
        config.get('signing_key', '')
        and not config.get('signing_passphrase')
        or config.get('signing_passphrase') == 'ask'
    ):
        passphrase = getpass('Enter key passphrase: ')
        config.set('signing_passphrase', passphrase)

    return config


def has_to_handle_signing_key(args, config):
    return (
        config.get('signing_key', '')
        and config.get('signing_passphrase') == 'ask'
        or
        args.repoaction == 'sign-rpms'
    )


def setup_logging(verbose=False):
    if verbose:
        setup_verbose_logging()
    else:
        setup_regular_logging()


def get_config(args):
    if args.config:
        config = config_mod.Config(path=args.config)
    else:
        config = config_mod.Config()

    config = handle_custom_options(args, config)

    if args.temp_dir:
        config.set('temp_dir', args.temp_dir)

    if args.stores:
        config.set('stores', args.stores)

    if args.with_sources:
        config.set('with_sources', 'true')

    if args.key:
        config.set('signing_key', args.key)
        config.set('signing_passphrase', args.passphrase)

    if has_to_handle_signing_key(args, config):
        config = set_signing_key(config)

    return config


def get_repo(args, config):
    if args.dir.endswith('/'):
        path = args.dir[:-1]
    else:
        path = args.dir

    return Repo(path=path, config=config)


def get_latest_repo(args, config, base_repo):
    return Repo(
        path=os.path.join(os.path.dirname(base_repo.path), 'latest'),
        config=config,
    )


def do_createrepo(repo):
    LOGGER.info('Regenerating repository metadata for %s', repo.path)
    repo.save()
    return 0


def do_sign_artifacts(repo):
    LOGGER.info('Signing all the artifacts at %s', repo.path)
    repo.save()
    return 0


def do_add(args, config, repo):
    if args.keep_latest < 0:
        LOGGER.error('keep-latest must be >0')
        return 1

    LOGGER.info('Adding artifacts to the repo %s', repo.path)
    for art_src in args.artifact_source:
        try:
            repo.add_source(art_src.strip())
        except Exception as e:
            LOGGER.error(e.message)
            LOGGER.error("Error while adding %s", art_src.strip())
            return 1

    if args.keep_latest > 0:
        header_msg = 'Removed'
        if args.noop:
            header_msg = 'Would have removed'
        # save beforehand to make sure that the rpm's inodes point to the new
        # repo before removing them
        repo.save()
        for artifact in repo.delete_old(
            num_to_keep=args.keep_latest,
            noop=args.noop
        ):
            LOGGER.info('%s %s', header_msg, artifact.path)
    else:
        LOGGER.info('')

    repo.save()

    if args.create_latest_repo:
        root_dir = os.path.dirname(repo.path)
        latest_repo = get_latest_repo(args, config, base_repo=repo)
        latest_repo.add_source('%s:latest' % root_dir)
        latest_repo.save()
        latest_repo.delete_old(num_to_keep=1)

    return 0


def do_remove_old(args, config, repo):
    if args.keep <= 0:
        LOGGER.error('keep must be >0')
        return 1

    header_msg = 'Removed'
    if args.noop:
        header_msg = 'Would have removed'
    for artifact in repo.delete_old(
        num_to_keep=args.keep,
        noop=args.noop
    ):
        logging.info('%s %s', header_msg, artifact)

    repo.save()


def do_generate_src(config, repo):
    config.set('with_sources', 'true')
    repo.save()
    return 0


def do_show_docs(args):
    if args.subject == 'config':
        print(config_mod.DEFAULT_CONFIG)
        for section in ('filters', 'sources', 'stores'):
            subject_mod = globals()[section]
            elements_dict = getattr(subject_mod, section.upper())
            for element in elements_dict.values():
                print(
                    '\n[%s.%s]' % (section[:-1], element.CONFIG_SECTION)
                    + '\n' + format_conf_options(element.DEFAULT_CONFIG)
                )
        return

    subject_mod = globals()[args.subject]
    elements_dict = getattr(
        subject_mod,
        args.subject.upper()
    )
    if not args.element:
        if args.subject == 'sources':
            extra_sources_doc = repo.Repo.add_source.__doc__
            print(
                'Meta-sources supported by add_source:\n%s' % extra_sources_doc
            )

        print(
            '\nAvailable %s:\n' % args.subject
        ) + '\n'.join(
            '  * ' + key for key in elements_dict
        )
    else:
        element = getattr(
            subject_mod,
            args.subject.upper()
        )[args.element]
        print(
            '==== %s.%s ====' % (args.subject, args.element)
            + str(element.__doc__)
            + '\n    Default config options'
            + '\n    ' + '-' * 70
            + '\n    [%s.%s]' % (args.subject[:-1], element.CONFIG_SECTION)
            + '\n' + format_conf_options(element.DEFAULT_CONFIG)
            + '\n    ' + '-' * 70
        )


def format_conf_options(conf_dict):
    return '\n'.join('    %s = %s' % item for item in iteritems(conf_dict))


def main():
    args = parse_args()

    setup_logging(args.verbose)

    if args.repoaction == 'docs':
        do_show_docs(args)
        return

    config = get_config(args)
    repo = get_repo(args, config)

    LOGGER.info('')
    exit_code = 0
    if args.repoaction == 'add':
        exit_code = do_add(args, config, repo)
    elif args.repoaction == 'generate-src':
        exit_code = do_generate_src(config, repo)
    elif args.repoaction == 'remove-old':
        exit_code = do_remove_old(args, config, repo)
    elif args.repoaction == 'createrepo':
        exit_code = do_createrepo(repo)
    elif args.repoaction in ['sign-rpms', 'sign-artifacts']:
        exit_code = do_sign_artifacts(repo)

    sys.exit(exit_code)
