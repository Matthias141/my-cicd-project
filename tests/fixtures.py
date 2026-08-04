"""
Shared test fixture values for the app/auth.py API-key surface.

API_KEYS is no longer a hardcoded module-level dict (see app/auth.py:
_load_api_keys) - it's populated at import time from Secrets Manager or
a local .env, and is empty by default. Tests need a known key injected
directly into auth.API_KEYS (see conftest.py's patched_api_keys fixture)
rather than relying on demo values that no longer exist in source.

TEST_API_KEY / TEST_API_SECRET are deliberately low-entropy, dictionary-word
values verified against Gitleaks locally (gitleaks detect finds zero
findings for either, including in the exact `api_key = '...'` /
`"secret": "..."` assignment shapes that flagged the old hardcoded
values) - not just "probably fine."
"""

TEST_API_KEY = "unittest-fixture-not-a-real-key"
TEST_API_SECRET = "unittest-fixture-not-a-real-secret"

TEST_API_KEY_INFO = {
    "name": "Test Client",
    "tier": "free",
    "rate_limit": 100,  # requests per minute
    "key_id": "unittest-fixture-key-id",
    "permissions": ["read"],
    "secret": TEST_API_SECRET,
}

# Separate key/value from TEST_API_KEY on purpose: tests that need to prove
# admin-only endpoints reject a non-admin key alongside accepting an admin
# one need two distinct keys present in API_KEYS at the same time, not one
# key whose permissions get mutated between assertions.
TEST_ADMIN_API_KEY = "unittest-fixture-not-a-real-admin-key"
TEST_ADMIN_API_SECRET = "unittest-fixture-not-a-real-admin-secret"

TEST_ADMIN_KEY_INFO = {
    "name": "Test Admin Client",
    "tier": "premium",
    "rate_limit": 1000,
    "key_id": "unittest-fixture-admin-key-id",
    "permissions": ["read", "write", "admin"],
    "secret": TEST_ADMIN_API_SECRET,
}
