"""Materialize GitHub release secrets without printing credentials."""

import base64
import os
from pathlib import Path


def prepare(environment):
    names = (
        "SANQI_ANDROID_STORE_PASSWORD",
        "SANQI_ANDROID_KEY_ALIAS",
        "SANQI_ANDROID_KEY_PASSWORD",
    )
    for name in (*names, "SANQI_ANDROID_KEYSTORE_BASE64", "SANQI_ANDROID_KEYSTORE_PATH", "GITHUB_ENV"):
        value = environment.get(name, "")
        if not value or "\n" in value or "\r" in value:
            raise ValueError(f"Missing or invalid {name}; configure the release secrets.")
    payload = base64.b64decode(environment["SANQI_ANDROID_KEYSTORE_BASE64"], validate=True)
    if not payload:
        raise ValueError("The upload keystore is empty.")
    path = Path(environment["SANQI_ANDROID_KEYSTORE_PATH"])
    # Never overwrite an existing key; restrict access even with a permissive umask.
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as output:
        output.write(payload)
    with open(environment["GITHUB_ENV"], "a", encoding="utf-8") as output:
        for name in names:
            output.write(f"{name}={environment[name]}\n")


if __name__ == "__main__":
    prepare(os.environ)
