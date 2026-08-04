"""
Shared pytest fixtures for the app/auth.py API-key surface.

API_KEYS is no longer a hardcoded module-level dict (see app/auth.py:
_load_api_keys) - it's populated at import time from Secrets Manager or
a local .env, and is empty by default. Tests that exercise
get_api_key_info() / validate_signature() / check_rate_limit() need a
known key injected directly into auth.API_KEYS rather than relying on
demo values that no longer exist in source. See fixtures.py for the
actual constant values and why they're Gitleaks-safe.
"""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))
sys.path.insert(0, os.path.dirname(__file__))

import pytest

from fixtures import TEST_API_KEY, TEST_API_KEY_INFO


@pytest.fixture
def patched_api_keys(monkeypatch):
    """
    Inject a single known test key into auth.API_KEYS for the duration
    of a test. monkeypatch auto-reverts afterward, so tests stay isolated
    from each other and from whatever real _load_api_keys() produced.
    """
    import auth
    monkeypatch.setattr(auth, "API_KEYS", {TEST_API_KEY: dict(TEST_API_KEY_INFO)})
    return auth.API_KEYS
