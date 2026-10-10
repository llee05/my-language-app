"""Offline importer regression: cached clips and repair without a real download."""

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tool import import_mandarin_audio as importer


class MandarinAudioImportTest(unittest.TestCase):
    def test_reuses_verified_clips_and_repairs_corrupted_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / "audio"
            output.mkdir()
            (output / "LICENSE.txt").write_text("fixture license")
            (root / "assets/data").mkdir(parents=True)
            (root / "assets/data/hsk_vocabulary.json").write_text(json.dumps([
                {"simplified": "你好", "pinyin": "nǐ hǎo", "hskLevel": 1},
            ]))
            audio = b"fixture recording bytes"
            tree = root / "tree.json"
            tree.write_text(json.dumps({
                "sha": importer.REVISION,
                "tree": [{
                    "path": "64k/hsk/cmn-你好.mp3", "type": "blob",
                    "size": len(audio), "sha": importer.blob_sha1(audio),
                }],
            }))
            with (
                patch.object(importer, "ROOT", root),
                patch.object(importer, "OUTPUT", output),
                patch("sys.argv", ["import", "--tree", str(tree)]),
                patch.object(importer, "fetch", return_value=audio) as fetch,
                contextlib.redirect_stdout(io.StringIO()),
            ):
                importer.main()
                fetch.assert_called_once()
                fetch.reset_mock()
                importer.main()
                fetch.assert_not_called()
                clip = output / "clips" / (importer.sha256(audio) + ".mp3")
                clip.write_bytes(b"damaged")
                with self.assertRaises(AssertionError):
                    importer.verify()
                previous_catalog = (output / "catalog.json").read_bytes()
                with self.assertRaises(AssertionError):
                    importer.refresh_metadata()
                self.assertEqual((output / "catalog.json").read_bytes(), previous_catalog)
                importer.main()
                fetch.assert_called_once()
                self.assertEqual(clip.read_bytes(), audio)
                importer.verify()
                fetch.reset_mock()
                (root / "assets/data/hsk_vocabulary.json").write_text(json.dumps([
                    {"simplified": "你好", "pinyin": "nǐ hao", "hskLevel": 2},
                ]))
                importer.refresh_metadata()
                fetch.assert_not_called()
                self.assertEqual(clip.read_bytes(), audio)
                updated = json.loads((output / "catalog.json").read_text())["clips"][0]
                self.assertEqual(updated["pinyin"], "nǐ hao")
                self.assertEqual(updated["hskLevel"], 2)
                self.assertEqual(updated["sourceBlob"], importer.blob_sha1(audio))


if __name__ == "__main__":
    unittest.main()
