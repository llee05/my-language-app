"""Read release identity from pubspec without requiring a Flutter installation."""

import json
import os
from pathlib import Path
import re
import sys


def release_metadata(pubspec, ref):
    versions = re.findall(
        r"^version:\s*([^\s#]+)\s*(?:#.*)?$", pubspec, re.MULTILINE
    )
    if len(versions) != 1:
        raise ValueError("pubspec.yaml must contain exactly one version")
    version = versions[0].strip("\"'")
    match = re.fullmatch(
        r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
        r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\+([1-9]\d*)",
        version,
    )
    if match is None:
        raise ValueError(
            "Use a semantic version with a positive build number, e.g. 1.0.0-beta.6+6"
        )
    prerelease = match.group(4)
    if prerelease and any(
        part.isdigit() and len(part) > 1 and part.startswith("0")
        for part in prerelease.split(".")
    ):
        raise ValueError("Numeric prerelease identifiers cannot contain leading zeroes")
    release_version, build_number = version.split("+")
    is_release = ref.startswith("refs/tags/v")
    if is_release and ref != f"refs/tags/v{release_version}":
        raise ValueError(f"Release tag must be v{release_version} to match pubspec.yaml")
    return {
        "version": version,
        "release_version": release_version,
        "build_number": build_number,
        "is_release": str(is_release).lower(),
        "prerelease": str(prerelease is not None).lower(),
    }


def main():
    metadata = release_metadata(
        Path("pubspec.yaml").read_text(), os.environ.get("GITHUB_REF", "")
    )
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a", encoding="utf-8") as stream:
            for key, value in metadata.items():
                stream.write(f"{key}={value}\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"Release metadata error: {error}", file=sys.stderr)
        sys.exit(1)
