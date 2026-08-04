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

from fixtures import (
    TEST_API_KEY,
    TEST_API_KEY_INFO,
    TEST_ADMIN_API_KEY,
    TEST_ADMIN_KEY_INFO,
)


@pytest.fixture
def patched_api_keys(monkeypatch):
    """
    Inject both known test keys (one non-admin, one admin) into
    auth.API_KEYS for the duration of a test. Both are present
    simultaneously so tests can verify a non-admin key is genuinely
    rejected from an admin-only endpoint while a real admin key is
    genuinely accepted, rather than mutating one key's permissions
    between assertions. monkeypatch auto-reverts API_KEYS afterward, so
    tests stay isolated from each other and from whatever real
    _load_api_keys() produced.

    Also clears auth.rate_limit_store before and after: it's a plain
    module-level dict, not something monkeypatch touches, and it's keyed
    by the same TEST_API_KEY constant tests/test_auth.py's
    TestRateLimiting tests use to deliberately exhaust the rate limit.
    Without clearing it here, any test using this fixture after those
    ones have run in the same session inherits an already-exhausted
    limit and gets a 429 instead of the response it's actually testing
    for - found via a stale-vs-current-main branch comparison, not
    something that showed up testing this fixture's own tests in
    isolation.
    """
    import auth
    monkeypatch.setattr(auth, "API_KEYS", {
        TEST_API_KEY: dict(TEST_API_KEY_INFO),
        TEST_ADMIN_API_KEY: dict(TEST_ADMIN_KEY_INFO),
    })
    auth.rate_limit_store.clear()
    yield auth.API_KEYS
    auth.rate_limit_store.clear()
