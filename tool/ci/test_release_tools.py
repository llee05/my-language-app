"""Offline regression checks for release identity and missing/corrupt downloads."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from prepare_release import expected_assets, prepare_release
from release_metadata import release_metadata


class ReleaseMetadataTest(unittest.TestCase):
    def test_beta_tag_matches_app_version_and_build(self):
        result = release_metadata("version: 1.0.0-beta.6+6\n", "refs/tags/v1.0.0-beta.6")
        self.assertEqual(result["release_version"], "1.0.0-beta.6")
        self.assertEqual(result["build_number"], "6")
        self.assertEqual(result["is_release"], "true")
        self.assertEqual(result["prerelease"], "true")

    def test_branch_and_pull_request_runs_do_not_release(self):
        for ref in ("refs/heads/main", "refs/pull/42/merge", "refs/heads/v1.0.0-beta.6", ""):
            with self.subTest(ref=ref):
                self.assertEqual(
                    release_metadata("version: 1.0.0-beta.6+6", ref)["is_release"], "false"
                )

    def test_stable_release_and_quoted_version(self):
        result = release_metadata("version: '1.0.0+7' # Release\n", "refs/tags/v1.0.0")
        self.assertEqual(result["prerelease"], "false")

    def test_mismatched_tag_fails_before_building(self):
        with self.assertRaisesRegex(ValueError, "tag must be v1.0.0-beta.6"):
            release_metadata("version: 1.0.0-beta.6+6", "refs/tags/v1.0.0-beta.5")

    def test_invalid_or_ambiguous_versions_fail(self):
        for pubspec in (
            "name: mylanguageapp",
            "version: 1.0.0+6\nversion: 1.0.1+7",
            "version: 1.0.0-beta.6",
            "version: 1.0.0+0",
            "version: 01.0.0+6",
            "version: 1.0.0-beta.06+6",
            "version: 1.0.0-beta/6+6",
        ):
            with self.subTest(pubspec=pubspec), self.assertRaises(ValueError):
                release_metadata(pubspec, "refs/heads/main")


class ReleaseAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.directory = self.root / "dist"
        self.directory.mkdir()
        self.metadata = release_metadata(
            "version: 1.0.0-beta.6+6", "refs/tags/v1.0.0-beta.6"
        )
        self.assets = expected_assets("1.0.0-beta.6")
        for name in self.assets:
            (self.directory / name).write_bytes(f"fixture: {name}".encode())

    def prepare(self):
        prepare_release(
            self.directory, self.metadata, "test-commit", "3.44.4", self.root / "notes.md"
        )

    def test_complete_release_has_verifiable_hashes_and_manifest(self):
        self.prepare()
        manifest = json.loads((self.directory / "release.json").read_text())
        self.assertEqual(manifest["version"], "1.0.0-beta.6+6")
        self.assertEqual(manifest["commit"], "test-commit")
        self.assertTrue(manifest["prerelease"])
        self.assertEqual(set(manifest["assets"]), self.assets)
        lines = (self.directory / "SHA256SUMS").read_text().splitlines()
        self.assertEqual(len(lines), len(self.assets) + 1)
        for line in lines:
            digest, name = line.split("  ", 1)
            self.assertEqual(
                digest, hashlib.sha256((self.directory / name).read_bytes()).hexdigest()
            )
        self.assertIn("notarization", (self.root / "notes.md").read_text())
        self.prepare()  # A failed publication can reuse the same asset preparation.

    def test_missing_platform_fails_without_generating_checksums(self):
        (self.directory / next(iter(self.assets))).unlink()
        with self.assertRaisesRegex(ValueError, "missing="):
            self.prepare()
        self.assertFalse((self.directory / "SHA256SUMS").exists())

    def test_unexpected_file_cannot_be_published(self):
        (self.directory / "key.properties").write_text("fixture")
        with self.assertRaisesRegex(ValueError, "unexpected=.*key.properties"):
            self.prepare()

    def test_empty_asset_fails(self):
        (self.directory / next(iter(self.assets))).write_bytes(b"")
        with self.assertRaisesRegex(ValueError, "nonempty regular file"):
            self.prepare()

    def test_symlink_asset_fails(self):
        name = next(iter(self.assets))
        (self.directory / name).unlink()
        (self.root / "outside").write_text("fixture")
        (self.directory / name).symlink_to(self.root / "outside")
        with self.assertRaisesRegex(ValueError, "nonempty regular file"):
            self.prepare()


if __name__ == "__main__":
    unittest.main()
