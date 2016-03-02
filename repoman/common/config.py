#!/usr/bin/env python
import os
import logging

from six.moves import StringIO
from six.moves import configparser as cp

from .stores import STORES
from .filters import FILTERS
from .sources import SOURCES


DEFAULT_CONFIG = """
[main]
allowed_repo_paths =
temp_dir = generate
singing_key =
signing_passphrase = ask
stores = all
filters = all
sources = all
verify_ssl = true
"""

logger = logging.getLogger(__name__ )  # flake8: noqa


class BadConfigError(Exception): pass  # flake8: noqa


def update_conf_from_plugin(config, plugins, prefix):
    # load all the configs from the sotres, on their sections
    for plugin in plugins.itervalues():
        conf_section = prefix + '.' + plugin.CONFIG_SECTION
        if not config.has_section(conf_section):
            config.add_section(conf_section)
        for opt_name, opt_value in plugin.DEFAULT_CONFIG.iteritems():
            if not config.has_option(conf_section, opt_name):
                config.set(conf_section, opt_name, opt_value)
            else:
                print config.get(conf_section, opt_name)


class Config(object):
    """
    Configuration object to wrap some config values.
    It keeps the configuration objects, one with the default values for all the
    sections and one with all the custom ones (from config files or set after).

    The resolution order is:
       custom_config(current_section -> main_section) ->
       default_config(current_section -> main_section)
    """
    def __init__(self, path=None, section='main'):
        self.section = section
        # load the specified file, if any
        self.config = cp.SafeConfigParser()
        self.config.add_section(self.section)
        if path:
            res = self.load(path)
            if not res:
                raise BadConfigError('Unable to load config %s' % path)
        self.default_config = cp.SafeConfigParser()
        self.default_config.readfp(StringIO(DEFAULT_CONFIG))
        self.load_plugins()

    def load_plugins(self):
        # load all the configs from the plugins, on their sections
        update_conf_from_plugin(self.default_config, STORES, 'store')
        update_conf_from_plugin(self.default_config, FILTERS, 'filter')
        update_conf_from_plugin(self.default_config, SOURCES, 'source')

    def load(self, path):
        return self.config.read((os.path.expanduser(path),))

    def __getattr__(self, what):
        try:
            val = getattr(self.config, what)
        except AttributeError:
            val = getattr(self.default_config, what)
        return val

    def set(self, entry, value):
        if not self.config.has_section(self.section):
            self.config.add_section(self.section)
        return self.config.set(self.section, entry, value)

    def _resolve_retrieval(self, entry, func_name):
        try:
            val = getattr(self.config, func_name)(self.section, entry)
        except (cp.NoOptionError, cp.NoSectionError):
            try:
                val = getattr(self.config, func_name)('main', entry)
            except (cp.NoOptionError, cp.NoSectionError):
                try:
                    val = getattr(
                        self.default_config, func_name
                    )(self.section, entry)
                except (cp.NoOptionError, cp.NoSectionError):
                    val = getattr(
                        self.default_config, func_name
                    )('main', entry)
        return val

    def get(self, entry, default=None):
        try:
            val = self._resolve_retrieval(entry, 'get')
        except (cp.NoOptionError, cp.NoSectionError):
            if default is not None:
                val = default
            else:
                raise
        return val

    def getboolean(self, entry, default=None):
        try:
            val = self._resolve_retrieval(entry, 'getboolean')
        except (cp.NoOptionError, cp.NoSectionError):
            if default is not None:
                val = default
            else:
                raise
        return val

    def getint(self, entry, default=None):
        try:
            val = self._resolve_retrieval(entry, 'getint')
        except (cp.NoOptionError, cp.NoSectionError):
            if default is not None:
                val = default
            else:
                raise
        return val

    def getfloat(self, entry, default=None):
        try:
            val = self._resolve_retrieval(entry, 'getfloat')
        except (cp.NoOptionError, cp.NoSectionError):
            if default is not None:
                val = default
            else:
                raise
        return val

    def getarray(self, entry, default=None):
        val = self.get(entry, default)
        val = [
            elem.strip()
            for elem in val.replace(',', '\n').splitlines()
            if elem.strip()
        ]
        return val

    def getdict(self, entry, default=None):
        val = self.get(entry, default)
        try:
            val = dict([
                [item.strip() for item in elem.strip().split('=')]
                for elem in val.replace(',', '\n').splitlines()
                if elem.strip()
            ])
        except Exception:
            raise RuntimeError(
                'Wrongly formatted option %s, expected a dict-like string in '
                'the form "%s = key1=val1, key2=val2..."'
                % (entry, entry)
            )
        return val

    def get_section(self, section):
        new_config = Config(section=section)
        new_config.config = self.config
        new_config.default_config = self.default_config
        return new_config

    def add_to_section(self, section, option, value):
        if not self.config.has_section(section):
            self.config.add_section(section)
        self.config.set(section, option, value)

    def __str__(self):
        my_str = '### Defaults:'
        for section in self.default_config.sections():
            my_str += "\n[%s]\n" % section
            for option in self.default_config.options(section):
                my_str += "%s = %s\n" % (
                    option,
                    self.default_config.get(section, option),
                )

        my_str += '\n\n### Config'
        for section in self.config.sections():
            my_str += "\n[%s]\n" % section
            for option in self.config.options(section):
                my_str += "%s = %s\n" % (
                    option,
                    self.config.get(section, option, ''),
                )

        my_str += '\n'

        return my_str
