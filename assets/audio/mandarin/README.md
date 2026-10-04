# Desktop Mandarin recordings

This pack contains **4,379 human-recorded vocabulary words** (47.3 MB of MP3s),
covering 87.7% of TingShuo's 4,991 HSK entries. Linux and Windows CMake builds
copy this directory to `data/mandarin_audio` beside the executable. It is
deliberately **not registered in pubspec.yaml**: Android, iOS, and macOS builds
do not include it. Keep the entire desktop bundle when distributing the app.

Recordings are Copyright © 2009 **Yue Tan**, from the Shtooka collection
**Collection audio libre de mots chinois (mandarins)**, recorded by the
University of Caen. Audio and derivatives are licensed under
[Creative Commons Attribution Share Alike 3.0 United States](https://creativecommons.org/licenses/by-sa/3.0/us/).
The original collection notice is preserved in [LICENSE.txt](LICENSE.txt).
An accessible original notice is maintained by the
[Yojik Shtooka archive](https://fsi-languages.yojik.eu/audiocollections/detailled/cmn-caen-tan/readme.txt).

MP3 conversion, filenames, and curation: **Hugo Lopez**, PLIDAM / INALCO,
[audio-cmn](https://github.com/hugolpz/audio-cmn), commit
`ff9ed3d0c631195bd2c06f39450f3264c7124040`. Recording software and technical
support: **Nicolas Vion**. TingShuo selects curriculum words, renames files
by their SHA-256 checksum, and adds the catalog; the MP3 bytes are unchanged
from the source's `64k/hsk/` directory. The audio pack and its catalog remain
available under CC BY-SA 3.0 US. This license applies to the recordings and
their catalog, separately from the application code.

The source is an older HSK word collection. Matching uses exact Hanzi filenames;
the source's MP3s do not retain pinyin tags. The catalog's `pinyin` describes
TingShuo's curriculum reading, **not a verified source transcription**.
Potentially ambiguous single characters listed in the importer are excluded
until their recorded reading can be reviewed. Missing words, examples,
sentence-practice cards, custom sentences, and generated dialogue use system
speech. Words are not spliced together to simulate a sentence.

From the repository root, regenerate with Python's standard library:

```sh
python3 tool/import_mandarin_audio.py
python3 tool/import_mandarin_audio.py --verify
```

Regeneration downloads public, pinned recordings and verifies each Git blob
SHA-1 against the source tree. Existing correct clips are reused. The offline
verification command checks SHA-256, byte lengths, source blob hashes, word
membership, pinyin, duplicate entries, and unreferenced files. Runtime playback
also verifies each clip's SHA-256 and keeps at most 64 compressed clips within
a 4 MiB memory budget. Failed reads are retried on the next playback request.

No learner data, models, credentials, or network service are included here.
