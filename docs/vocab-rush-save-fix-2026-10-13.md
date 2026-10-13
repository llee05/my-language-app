# Vocab Rush save handling — 13 October 2026

Vocab Rush previously advanced after 450 milliseconds while saving independently.
A slow or failed save could outlive the card, game, or page; retry depended on a
temporary snackbar. The game now keeps its submitted answer until persistence
succeeds, while retaining the existing feedback delay for fast saves.

Timeout and Back defer results until the submitted answer saves. Sidebar and
Profile navigation preserve a pending or failed submission. A persistent inline
error provides **Try again**; repeated retry clicks cannot overlap. Retries retain
the same word, correctness, submission key, and original review-queue date.
When the review has already committed but queue insertion fails, retry only
repeats the queue operation. Statistics refresh after the review commits, and
game scores are counted once. Feedback timers are cancelled on restart/disposal.

Cancellable desktop exit requests delivered to Flutter are refused while an
answer remains unsaved. After the answer saves, the game ends; the user can close
the app again. This is a guard for normal navigation and supported close events,
not a persisted outbox: forced process termination or power loss can still lose
an answer that has not committed. Timed games continue counting during ordinary
background time and saving, stopping at expiry or an explicit finish request.

The Start/Play Again button now wraps its bilingual label, fixing an overflow
found while testing failed-save recovery at 320 pixels with double-sized text.
No database schema, content asset, dependency, scoring rule, or version changed.

Nine added regressions cover slow saves before advancing, Back, timeout and
desktop exit; persistent failure and duplicate retry clicks; mobile recovery;
late completion after disposal; the third strike; and actual sidebar/Profile
navigation. The existing queue-failure test additionally checks a retry across
midnight, one committed review, and one statistics refresh. The mode-selection
test uses repository doubles rather than depending on SQLite startup completing
within the answer-feedback delay.

Validation used Flutter 3.44.4 and Dart 3.12.2:

- Required format check: 173 Dart files, no changes needed.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --coverage --concurrency=2`: all 689 tests passed,
  including all 25 Vocab Rush cases.
- The initial full run had two 30-second database-restore timeouts while native
  builds were running. Both tests passed separately, and the entire suite then
  passed with builds finished and two test workers. Timeout limits were unchanged.
- Linux release and Android debug builds both passed. Android reported its
  existing Kotlin plugin migration warning.
- `git diff --check`: clean.

Windows/macOS builds, physical-device speech/backup checks, and signed Android
upgrade testing remain separate release checks. No learner database, personal
credentials, or operating-system configuration was changed by these tests.
