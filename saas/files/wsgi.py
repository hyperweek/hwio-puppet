import os, sys

# This is because portable WSGI applications should not write to sys.stdout or
# use the 'print' statement without specifying an alternate file object
# besides sys.stdout as the target.
sys.stdout = sys.stderr

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "app.settings")

import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()
