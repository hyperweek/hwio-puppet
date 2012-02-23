import ConfigParser

__all__ = ['config']


def read_config(config_file='app.ini'):
    parser = ConfigParser.ConfigParser()
    parser.read([config_file])
    site = {}
    for section in parser.sections():
        site[section] = dict(parser.items(section))

    return site

config = read_config()
