#!/usr/bin/env python3
"""Import pinned, human-recorded Mandarin MP3s for Linux/Windows bundles.

Uses only the standard library. Existing clips are verified and reused. No
network access is needed by the app or by --verify.
"""

import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import time
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/audio/mandarin"
REVISION = "ff9ed3d0c631195bd2c06f39450f3264c7124040"
SOURCE = "https://github.com/hugolpz/audio-cmn"
RAW = f"https://raw.githubusercontent.com/hugolpz/audio-cmn/{REVISION}/"
# The source names clips by Hanzi, losing the original reading metadata.
# Keep these polyphonic single characters on system speech until their source
# reading can be reviewed. Multi-character words retain their lexical context.
AMBIGUOUS = set(
    "了会几哪喂和好少没的看谁那都为别号得着累还长分只啊地差把教更种角难假发"
    "场干弄弹当省血行乘便倒冲切卷吐吓呆唉嚷圈提晕朝横正涨片盖系背臭薄蛇重露"
    "呵咋哄哦哼嗯巷幢扁扎扒扛折拧拽拾挨捎搁搂攒数淋溜熬番盛眯磅秤翘蒙铺"
)


def fetch(url):
    for attempt in range(4):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "TingShuo-audio-import"}
            )
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except Exception:
            if attempt == 3:
                raise
            time.sleep(attempt + 1)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def blob_sha1(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def verify():
    catalog = json.loads((OUTPUT / "catalog.json").read_text())
    assert catalog["version"] == 1 and catalog["revision"] == REVISION
    vocabulary = {
        word["simplified"]: word
        for word in json.loads((ROOT / "assets/data/hsk_vocabulary.json").read_text())
    }
    seen = set()
    for entry in catalog["clips"]:
        text = entry["text"]
        assert text not in seen and text in vocabulary and text not in AMBIGUOUS
        seen.add(text)
        assert entry["pinyin"] == vocabulary[text]["pinyin"]
        assert entry["file"] == entry["sha256"] + ".mp3"
        data = (OUTPUT / "clips" / entry["file"]).read_bytes()
        assert len(data) == entry["bytes"] and sha256(data) == entry["sha256"]
        assert blob_sha1(data) == entry["sourceBlob"]
    assert {p.name for p in (OUTPUT / "clips").glob("*.mp3")} == {
        e["file"] for e in catalog["clips"]
    }
    assert (OUTPUT / "LICENSE.txt").is_file()
    size = sum(e["bytes"] for e in catalog["clips"]) / 1_000_000
    print(f"Verified {len(seen)} recordings ({size:.1f} MB).")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument(
        "--tree", type=Path, help="Use a previously downloaded GitHub tree JSON"
    )
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args()
    if args.verify:
        verify()
        return
    tree = json.loads(
        args.tree.read_text() if args.tree else fetch(
            f"https://api.github.com/repos/hugolpz/audio-cmn/git/trees/{REVISION}?recursive=1"
        )
    )
    assert tree["sha"] == REVISION and not tree.get("truncated")
    blobs = {entry["path"]: entry for entry in tree["tree"] if entry["type"] == "blob"}
    words = json.loads((ROOT / "assets/data/hsk_vocabulary.json").read_text())
    wanted = [
        word for word in words
        if word["simplified"] not in AMBIGUOUS
        and f"64k/hsk/cmn-{word['simplified']}.mp3" in blobs
    ]
    clips_dir = OUTPUT / "clips"
    clips_dir.mkdir(parents=True, exist_ok=True)
    old = {}
    if (OUTPUT / "catalog.json").exists():
        old = {
            e["text"]: e
            for e in json.loads((OUTPUT / "catalog.json").read_text())["clips"]
        }

    def import_word(word):
        text = word["simplified"]
        source_path = f"64k/hsk/cmn-{text}.mp3"
        blob = blobs[source_path]
        previous = old.get(text)
        data = None
        if previous and previous["sourceBlob"] == blob["sha"]:
            path = clips_dir / previous["file"]
            if path.exists() and sha256(path.read_bytes()) == previous["sha256"]:
                data = path.read_bytes()
        if data is None:
            data = fetch(RAW + urllib.parse.quote(source_path))
        assert len(data) == blob["size"]
        assert blob_sha1(data) == blob["sha"]
        digest = sha256(data)
        filename = digest + ".mp3"
        path = clips_dir / filename
        if not path.exists() or sha256(path.read_bytes()) != digest:
            path.write_bytes(data)
        return {
            "text": text, "pinyin": word["pinyin"], "hskLevel": word["hskLevel"],
            "file": filename, "bytes": len(data), "sha256": digest,
            "sourcePath": source_path, "sourceBlob": blob["sha"],
        }

    clips = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for entry in pool.map(import_word, wanted):
            clips.append(entry)
            if len(clips) % 250 == 0:
                print(f"Imported {len(clips)}/{len(wanted)}", flush=True)
    catalog = {
        "version": 1, "source": SOURCE, "revision": REVISION, "speaker": "Yue Tan",
        "license": "CC-BY-SA-3.0-US",
        "licenseUrl": "https://creativecommons.org/licenses/by-sa/3.0/us/",
        "readingPolicy": "Hanzi word matches; ambiguous single characters excluded. Pinyin is curriculum metadata, not source-verified transcription.",
        "clips": clips,
    }
    (OUTPUT / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    )
    used = {entry["file"] for entry in clips}
    for path in clips_dir.glob("*.mp3"):
        if path.name not in used:
            path.unlink()
    verify()


if __name__ == "__main__":
    main()
