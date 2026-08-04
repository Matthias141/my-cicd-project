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
