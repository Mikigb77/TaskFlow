from .test_settings import *  # noqa: F403
from .settings import DATABASES  # noqa: F401

# Django creates an isolated test_<name> database. Retain the local-memory
# cache/email overrides so concurrency checks cannot clear development quotas.
