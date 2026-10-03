"""Require the complete platform asset set and generate release checksums/notes."""

import argparse
import hashlib
import json
from pathlib import Path
import sys

from release_metadata import release_metadata


def expected_assets(version):
    prefix = f"tingshuo-{version}"
    return {
        f"{prefix}-linux-x64.tar.gz",
        f"{prefix}-macos-universal-unsigned.zip",
        f"{prefix}-windows-x64.zip",
        f"{prefix}-android.apk",
        f"{prefix}-android.aab",
    }


def prepare_release(directory, metadata, commit, flutter_version, notes_path):
    expected = expected_assets(metadata["release_version"])
    actual = {path.name for path in directory.iterdir()}
    # Allow regenerating our own outputs, but never publish unrelated artifacts.
    actual -= {"SHA256SUMS", "release.json"}
    if actual != expected:
        raise ValueError(
            f"Incomplete release: missing={sorted(expected - actual)}, "
            f"unexpected={sorted(actual - expected)}"
        )
    for name in sorted(expected):
        path = directory / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
            raise ValueError(f"Release asset must be a nonempty regular file: {name}")
    manifest = {
        "version": metadata["version"],
        "tag": f"v{metadata['release_version']}",
        "commit": commit,
        "flutter_version": flutter_version,
        "prerelease": metadata["prerelease"] == "true",
        "macos_signing": "ad-hoc, not Developer ID signed or notarized",
        "windows_signing": "unsigned",
        "assets": sorted(expected),
    }
    (directory / "release.json").write_text(json.dumps(manifest, indent=2) + "\n")
    checksums = []
    for name in sorted(expected | {"release.json"}):
        digest = hashlib.sha256()
        with (directory / name).open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        checksums.append(f"{digest.hexdigest()}  {name}\n")
    (directory / "SHA256SUMS").write_text("".join(checksums))
    version = metadata["release_version"]
    notes_path.write_text(
        f"## Downloads for {version}\n\n"
        "- **Linux x64:** extract the `.tar.gz` and run `tingshuo` inside the extracted folder. "
        "Keep its `lib` and `data` directories beside it. Built on Ubuntu 22.04; "
        "native audio and keyring libraries still require platform testing.\n"
        "- **macOS Intel / Apple Silicon:** extract the universal `.zip` and move "
        "`TingShuo.app` to Applications. This beta is ad-hoc signed, without Apple "
        "Developer ID signing or notarization; Gatekeeper may block it. "
        "See the README for installation and platform limitations.\n"
        "- **Windows x64:** extract the whole `.zip` and run `tingshuo.exe`. "
        "Keep the DLLs and `data` directory beside it. This beta is unsigned.\n"
        "- **Android:** install the signed `.apk` directly; the `.aab` is for Play Console.\n\n"
        "`SHA256SUMS` contains SHA-256 hashes for every download and `release.json`. "
        "The manifest records the source commit, app/build version, and Flutter version.\n\n"
        "Learning data stays on your device. Back it up in Settings before upgrading. "
        "No shared AI key is embedded; personal AI configuration remains optional.\n\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    parser.add_argument("--ref", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--flutter-version", required=True)
    parser.add_argument("--notes", type=Path, required=True)
    args = parser.parse_args()
    metadata = release_metadata(args.pubspec.read_text(), args.ref)
    if metadata["is_release"] != "true":
        raise ValueError("Release preparation requires a matching version tag")
    prepare_release(args.directory, metadata, args.commit, args.flutter_version, args.notes)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        print(f"Release preparation error: {error}", file=sys.stderr)
        sys.exit(1)
