#!/usr/bin/env python
import os, sys

if __name__ == "__main__":
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "app.settings")
    # Add the project directory to the path, to appease billiard
    # See: http://stackoverflow.com/a/13147854
    os.environ.setdefault("DJANGO_PROJECT_DIR", os.path.dirname(os.path.realpath(__file__)))

    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)
