part of '../widget_test.dart';

class _FakePronunciationService
    implements PronunciationService, PreparedPronunciationService {
  final List<String> prepared = [];

  @override
  Future<void> prepareMandarin(String text) async {
    prepared.add(text);
  }

  final StreamController<OfflineVoiceStatus> _updates =
      StreamController<OfflineVoiceStatus>.broadcast();
  final List<String> spoken = [];
  OfflineVoiceStatus status = const OfflineVoiceStatus.notInstalled();
  int installCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<OfflineVoiceStatus> get offlineVoiceUpdates => _updates.stream;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async => status;

  @override
  Future<void> installOfflineVoice() async {
    installCalls++;
    status = const OfflineVoiceStatus.ready();
    _updates.add(status);
  }

  @override
  Future<void> speakMandarin(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {
    if (disposeCalls > 0) return;
    disposeCalls++;
    await _updates.close();
  }
}

class _FailOncePronunciationService extends _FakePronunciationService {
  bool _failNext = true;

  @override
  Future<void> speakMandarin(String text) async {
    if (_failNext) {
      _failNext = false;
      throw StateError('Audio temporarily unavailable');
    }
    await super.speakMandarin(text);
  }
}

class _RecordedFakePronunciationService extends _FakePronunciationService
    implements RecordedAudioPronunciation, DesktopVoiceInstaller {
  bool installed = false;
  bool failCheck = false;
  bool failInstall = false;
  bool readyAfterInstall = true;
  int voiceCheckCalls = 0;
  int voiceInstallCalls = 0;
  Future<void>? installationGate;

  @override
  Future<bool> isMandarinVoiceInstalled() async {
    voiceCheckCalls++;
    if (failCheck) throw StateError('Voice enumeration failed');
    return installed;
  }

  @override
  Future<void> installMandarinVoice() async {
    voiceInstallCalls++;
    if (failInstall) {
      throw const DesktopVoiceInstallationException(
        'Administrator approval was cancelled.',
      );
    }
    await installationGate;
    installed = readyAfterInstall;
  }

  @override
  String get systemSpeechDescription =>
      'Missing words use system Mandarin speech.';

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus(
        state: OfflineVoiceState.ready,
        message: '4379 human-recorded words are bundled and ready offline.',
      );
}

class _ManagedFakePronunciationService extends _FakePronunciationService
    implements OfflinePronunciationManager {
  _ManagedFakePronunciationService({
    OfflineVoiceStatus kokoroStatus = const OfflineVoiceStatus.notInstalled(
      engine: PronunciationEngine.kokoro,
      totalBytes: kokoroOfflineVoiceDownloadBytes,
    ),
  }) {
    _kokoroStatus = kokoroStatus;
  }

  final StreamController<OfflineVoiceStatus> _voicePackUpdates =
      StreamController<OfflineVoiceStatus>.broadcast();
  late OfflineVoiceStatus _kokoroStatus;
  final List<PronunciationEngine> installedEngines = [];
  PronunciationEngine? configuredEngine;
  List<String> configuredVoiceIds = const [];

  @override
  Stream<OfflineVoiceStatus> get voicePackUpdates => _voicePackUpdates.stream;

  @override
  Future<OfflineVoiceStatus> checkVoicePack(PronunciationEngine engine) async =>
      _kokoroStatus;

  @override
  Future<void> installVoicePack(PronunciationEngine engine) async {
    installedEngines.add(engine);
    final ready = OfflineVoiceStatus.ready(engine: engine);
    _kokoroStatus = ready;
    _voicePackUpdates.add(ready);
  }

  @override
  List<PronunciationVoice> voicesFor(PronunciationEngine engine) =>
      kokoroMandarinVoices;

  @override
  Future<void> configurePronunciation({
    required PronunciationEngine engine,
    List<String> voiceIds = const [],
  }) async {
    configuredEngine = engine;
    configuredVoiceIds = List.of(voiceIds);
  }

  @override
  Future<void> dispose() async {
    if (!_voicePackUpdates.isClosed) await _voicePackUpdates.close();
    await super.dispose();
  }
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([this.settings = const LearnerSettings()]);

  LearnerSettings settings;

  @override
  Future<LearnerSettings> load() async => settings;

  @override
  Future<void> save(LearnerSettings settings) async {
    this.settings = settings;
  }
}

class _PendingSettingsRepository extends _MemorySettingsRepository {
  final saveGate = Completer<void>();
  bool saveStarted = false;

  @override
  Future<void> save(LearnerSettings settings) async {
    saveStarted = true;
    await saveGate.future;
    await super.save(settings);
  }
}

class _EmptyTutorContextRepository implements TutorContextRepository {
  @override
  Future<TutorLearnerSnapshot> load({required DateTime asOf}) async =>
      TutorLearnerSnapshot(asOf: asOf);
}

class _GatedSettingsRepository extends _MemorySettingsRepository {
  _GatedSettingsRepository(this.saveGate);

  final Completer<void> saveGate;

  @override
  Future<void> save(LearnerSettings settings) async {
    await saveGate.future;
    await super.save(settings);
  }
}

class _FailOnceSettingsLoadRepository implements SettingsRepository {
  _FailOnceSettingsLoadRepository(this.settings);

  final LearnerSettings settings;
  int loadCalls = 0;

  @override
  Future<LearnerSettings> load() async {
    loadCalls++;
    if (loadCalls == 1) {
      throw StateError('sensitive settings path /private/preferences.db');
    }
    return settings;
  }

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _FailOnceSettingsSaveRepository extends _MemorySettingsRepository {
  _FailOnceSettingsSaveRepository(super.settings);

  final List<LearnerSettings> saveAttempts = [];

  @override
  Future<void> save(LearnerSettings settings) async {
    saveAttempts.add(settings);
    if (saveAttempts.length == 1) {
      throw StateError('sensitive settings path /private/preferences.db');
    }
    await super.save(settings);
  }
}

class _FailingSettingsRepository implements SettingsRepository {
  @override
  Future<LearnerSettings> load() =>
      Future.error(StateError('preferences unavailable'));

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _FailAfterFirstSettingsRepository implements SettingsRepository {
  int loadCalls = 0;

  @override
  Future<LearnerSettings> load() async {
    loadCalls++;
    if (loadCalls > 1) throw StateError('preferences temporarily unavailable');
    return const LearnerSettings(showPinyin: false);
  }

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _StalledSettingsRepository implements SettingsRepository {
  final _result = Completer<LearnerSettings>();

  @override
  Future<LearnerSettings> load() => _result.future;

  @override
  Future<void> save(LearnerSettings settings) async {}
}

class _MemoryDevelopmentRepository implements DevelopmentRepository {
  _MemoryDevelopmentRepository({this.onReset});

  final Future<void> Function()? onReset;
  int resetAllDataCalls = 0;

  @override
  Future<String> databasePath() async => 'memory';

  @override
  Future<void> resetAllData() async {
    resetAllDataCalls++;
    final callback = onReset;
    if (callback != null) await callback();
  }
}

class _ZeroRandom implements Random {
  int nextIntCalls = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    nextIntCalls++;
    return 0;
  }
}

class _MemoryLearnerRepository implements LearnerRepository {
  _MemoryLearnerRepository(this.profile);

  LearnerProfile? profile;
  int resetOnboardingCalls = 0;

  @override
  Future<void> resetOnboarding() async {
    resetOnboardingCalls++;
    profile = null;
  }

  @override
  Future<LearnerProfile?> load() async => profile;

  @override
  Future<void> save(LearnerProfile profile) async {
    this.profile = profile;
  }
}

class _MemoryLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  final lesson = const Lesson(
    summary: LessonSummary(
      id: 7,
      title: 'Saved lesson',
      theme: 'Saved',
      hskLevel: 1,
    ),
    cards: [
      Flashcard(id: 11, chinese: '你', pinyin: 'nǐ', englishMeaning: 'you'),
      Flashcard(id: 12, chinese: '学', pinyin: 'xué', englishMeaning: 'study'),
    ],
  );

  @override
  Future<Lesson?> findById(int id) async =>
      id == lesson.summary.id ? lesson : null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => lesson;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}

  @override
  Future<List<LessonSummary>> topics() async => [lesson.summary];
}

class _ExampleLessonRepository extends _MemoryLessonRepository {
  @override
  Future<Lesson?> findById(int id) async => Lesson(
    summary: lesson.summary,
    cards: const [
      Flashcard(
        id: 11,
        chinese: '你',
        pinyin: 'nǐ',
        englishMeaning: 'you',
        exampleChinese: '  ',
      ),
      Flashcard(
        id: 12,
        chinese: '学',
        pinyin: 'xué',
        englishMeaning: 'study',
        exampleChinese: '我学中文。',
        examplePinyin: 'Wǒ xué Zhōngwén.',
        exampleEnglish: 'I study Chinese.',
      ),
    ],
  );
}

class _ArchivedLessonRepository extends _MemoryLessonRepository {
  @override
  Future<List<LessonSummary>> topics() async => [];
}

class _GuidedLessonRepository extends _MemoryLessonRepository {
  @override
  Future<Lesson?> findById(int id) async => Lesson(
    summary: lesson.summary,
    cards: lesson.cards,
    guide: savedLessonGuide,
  );
}

class _MultiLevelLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  static const hsk1Lesson = LessonSummary(
    id: 41,
    title: 'Morning Greetings',
    theme: 'Greetings',
    hskLevel: 1,
  );
  static const hsk3Lesson = LessonSummary(
    id: 42,
    title: 'Restaurant Talk',
    theme: 'Dining Out',
    hskLevel: 3,
  );
  static const hsk4Lesson = LessonSummary(
    id: 43,
    title: 'Market News',
    theme: 'News and Media',
    hskLevel: 4,
  );

  @override
  Future<List<LessonSummary>> topics() async => const [
    hsk1Lesson,
    hsk3Lesson,
    hsk4Lesson,
  ];

  @override
  Future<Lesson?> findById(int id) async => null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _RotatingLessonRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  _RotatingLessonRepository({
    this.missingIds = const {},
    this.emptyIds = const {},
  });

  final Set<int> missingIds;
  final Set<int> emptyIds;
  final requestedIds = <int>[];
  late final List<Lesson> lessons = [
    for (var level = 1; level <= 6; level++)
      for (var variant = 1; variant <= 2; variant++)
        Lesson(
          summary: LessonSummary(
            id: level * 10 + variant,
            title: 'HSK $level lesson $variant',
            theme: 'Level $level theme $variant',
            hskLevel: level,
          ),
          cards: [
            Flashcard(
              id: level * 100 + variant * 10 + 1,
              chinese: '学',
              pinyin: 'xué',
              englishMeaning: 'study',
            ),
            Flashcard(
              id: level * 100 + variant * 10 + 2,
              chinese: '习',
              pinyin: 'xí',
              englishMeaning: 'practice',
            ),
          ],
        ),
  ];

  @override
  Future<List<LessonSummary>> topics() async =>
      lessons.map((lesson) => lesson.summary).toList(growable: false);

  @override
  Future<Lesson?> findById(int id) async {
    requestedIds.add(id);
    if (missingIds.contains(id)) return null;
    final lesson = lessons.cast<Lesson?>().firstWhere(
      (lesson) => lesson?.summary.id == id,
      orElse: () => null,
    );
    if (lesson != null && emptyIds.contains(id)) {
      return Lesson(summary: lesson.summary, cards: const []);
    }
    return lesson;
  }

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _LessonStateRepository implements LessonRepository {
  @override
  Future<void> deleteGenerated(int lessonId) async {
    throw UnimplementedError();
  }

  _LessonStateRepository({this.firstTopics, this.failFirstTopicsLoad = false});

  final Future<List<LessonSummary>>? firstTopics;
  final bool failFirstTopicsLoad;
  int topicsCalls = 0;

  static const lesson = Lesson(
    summary: LessonSummary(
      id: 27,
      title: 'Recovered lesson',
      theme: 'Recovery',
      hskLevel: 2,
    ),
    cards: [
      Flashcard(id: 271, chinese: '好', pinyin: 'hǎo', englishMeaning: 'good'),
    ],
  );

  @override
  Future<List<LessonSummary>> topics() async {
    topicsCalls++;
    if (topicsCalls == 1) {
      if (firstTopics case final firstTopics?) return firstTopics;
      if (failFirstTopicsLoad) {
        throw StateError('sensitive database path /private/lessons.db');
      }
    }
    return [lesson.summary];
  }

  @override
  Future<Lesson?> findById(int id) async =>
      id == lesson.summary.id ? lesson : null;

  @override
  Future<Lesson?> findGenerated({
    required String theme,
    required int hskLevel,
  }) async => null;

  @override
  Future<Flashcard> findOrCreateVocabularyCard({
    required Flashcard card,
    required int hskLevel,
  }) async => card;

  @override
  Future<void> saveGenerated(Lesson lesson) async {}
}

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository({
    this.hasActiveSession = true,
    this.queue = const [],
    List<ReviewRecord>? reviews,
    this.vocabulary = const [],
    this.recordReviewGate,
    LessonSession? activeSession,
  }) : reviews =
           reviews ??
           (hasActiveSession
               ? [
                   ReviewRecord(
                     id: 1,
                     cardId: 11,
                     sessionId: 3,
                     submissionKey: 'lesson:3:card:11',
                     reviewedAt: DateTime.utc(2026, 7, 28, 9),
                     rating: ReviewRating.easy,
                     wasCorrect: true,
                   ),
                 ]
               : const []),
       _active =
           activeSession ??
           LessonSession(
             id: 3,
             lessonId: 7,
             startedAt: DateTime.utc(2026, 7, 28),
             currentCardIndex: 1,
             cardsReviewed: 1,
             correctAnswers: 1,
           );

  final bool hasActiveSession;
  final List<DailyQueueCard> queue;
  final List<ReviewRecord> reviews;
  final List<VocabularyCardProgress> vocabulary;
  final Completer<void>? recordReviewGate;
  int dailyQueueCalls = 0;
  int recordReviewCalls = 0;
  final List<DateTime> requestedDays = [];
  LessonSession? savedSession;
  ReviewRecord? recordedReview;
  CardProgress? savedProgress;
  int? startedLessonId;

  final LessonSession _active;

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async =>
      hasActiveSession ? _active : null;

  @override
  Future<LessonSession?> latestActiveSession() async =>
      hasActiveSession ? _active : null;

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async => const [];

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) async {
    dailyQueueCalls++;
    requestedDays.add(forDay);
    return queue.take(limit).toList(growable: false);
  }

  @override
  Future<CardProgress?> progressForCard(int cardId) async => null;

  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => vocabulary;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    recordReviewCalls++;
    recordedReview = review;
    savedProgress = progress;
    await recordReviewGate?.future;
  }

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      reviews
          .where((review) => cardId == null || review.cardId == cardId)
          .take(limit ?? reviews.length)
          .toList(growable: false);

  @override
  Future<LessonSession> startSession(int lessonId) async {
    startedLessonId = lessonId;
    return _active;
  }

  @override
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}

  @override
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  }) async {
    savedSession = session;
  }
}

class _FailOnceRecordReviewRepository extends _MemoryProgressRepository {
  int recordReviewAttempts = 0;

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    recordReviewAttempts++;
    if (recordReviewAttempts == 1) {
      throw StateError('sensitive database path /private/reviews.db');
    }
    await super.recordReview(review: review, progress: progress);
  }
}

class _DeferredDailyQueueRepository extends _MemoryProgressRepository {
  _DeferredDailyQueueRepository(this.result);

  final Completer<List<DailyQueueCard>> result;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) {
    dailyQueueCalls++;
    requestedDays.add(forDay);
    return result.future;
  }
}

class _FailOnceDailyQueueRepository extends _MemoryProgressRepository {
  _FailOnceDailyQueueRepository({required super.queue});

  bool _shouldFail = true;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) {
    if (_shouldFail) {
      _shouldFail = false;
      dailyQueueCalls++;
      requestedDays.add(forDay);
      return Future.error(StateError('sensitive database path'));
    }
    return super.dailyQueue(
      forDay: forDay,
      limit: limit,
      weakThreshold: weakThreshold,
      maxHskLevel: maxHskLevel,
    );
  }
}

class _SequencedDailyQueueRepository extends _MemoryProgressRepository {
  _SequencedDailyQueueRepository(this.results);

  final List<Completer<List<DailyQueueCard>>> results;
  int _nextResult = 0;

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) {
    dailyQueueCalls++;
    requestedDays.add(forDay);
    return results[_nextResult++].future;
  }
}

class _MemoryDailyReviewSessionRepository
    implements DailyReviewSessionRepository {
  _MemoryDailyReviewSessionRepository(this.session);

  DailyReviewSession? session;

  @override
  Future<DailyReviewSession?> load(DateTime date) async => session;

  @override
  Future<DailyReviewSession> create({
    required DateTime date,
    required List<int> queuedCardIds,
  }) async => session!;

  @override
  Future<void> update(DailyReviewSession session) async {
    this.session = session;
  }

  @override
  Future<bool> complete({
    required int sessionId,
    required DateTime completedAt,
    required int expectedCardCount,
  }) async {
    final current = session!;
    session = DailyReviewSession(
      id: current.id,
      date: current.date,
      queuedCardIds: current.queuedCardIds,
      currentPosition: current.queuedCardIds.length,
      completedAt: completedAt,
    );
    return true;
  }

  @override
  Future<void> enqueueCard({
    required DateTime date,
    required int cardId,
  }) async {}
}

class _JourneyReviewRepository
    implements ProgressRepository, DailyReviewSessionRepository {
  static const _cards = [
    DailyQueueCard(
      card: Flashcard(id: 1, chinese: '一', pinyin: 'yī', englishMeaning: 'one'),
      reason: DailyQueueReason.newWord,
    ),
    DailyQueueCard(
      card: Flashcard(id: 2, chinese: '二', pinyin: 'èr', englishMeaning: 'two'),
      reason: DailyQueueReason.weak,
    ),
  ];

  final Map<String, DailyReviewSession> sessions = {};
  final Map<int, CardProgress> progress = {};
  final List<ReviewRecord> savedReviews = [];
  int createdSessionCount = 0;
  int reviewCount = 0;
  int? cardToAppendOnNextCompletion;

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Future<List<DailyQueueCard>> dailyQueue({
    required DateTime forDay,
    required int limit,
    double weakThreshold = .7,
    int maxHskLevel = 6,
  }) async {
    final key = _key(forDay);
    final session =
        sessions[key] ??
        await create(
          date: forDay,
          queuedCardIds: _cards.map((item) => item.card.id).toList(),
        );
    final cardsById = {for (final item in _cards) item.card.id: item};
    return session.queuedCardIds
        .skip(session.currentPosition)
        .map((id) => cardsById[id]!)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<DailyReviewSession> create({
    required DateTime date,
    required List<int> queuedCardIds,
  }) async {
    final key = _key(date);
    final existing = sessions[key];
    if (existing != null) return existing;
    final session = DailyReviewSession(
      id: createdSessionCount + 1,
      date: DateTime(date.year, date.month, date.day),
      queuedCardIds: List.unmodifiable(queuedCardIds),
    );
    sessions[key] = session;
    createdSessionCount++;
    return session;
  }

  @override
  Future<DailyReviewSession?> load(DateTime date) async => sessions[_key(date)];

  @override
  Future<void> update(DailyReviewSession session) async {
    sessions[_key(session.date)] = session;
  }

  @override
  Future<bool> complete({
    required int sessionId,
    required DateTime completedAt,
    required int expectedCardCount,
  }) async {
    final entry = sessions.entries.singleWhere(
      (entry) => entry.value.id == sessionId,
    );
    final current = entry.value;
    final cardToAppend = cardToAppendOnNextCompletion;
    if (cardToAppend != null) {
      cardToAppendOnNextCompletion = null;
      sessions[entry.key] = DailyReviewSession(
        id: current.id,
        date: current.date,
        queuedCardIds: [...current.queuedCardIds, cardToAppend],
        currentPosition: expectedCardCount,
      );
      return false;
    }
    sessions[entry.key] = DailyReviewSession(
      id: current.id,
      date: current.date,
      queuedCardIds: current.queuedCardIds,
      currentPosition: current.queuedCardIds.length,
      completedAt: completedAt,
    );
    return true;
  }

  @override
  Future<void> enqueueCard({
    required DateTime date,
    required int cardId,
  }) async {}

  @override
  Future<CardProgress?> progressForCard(int cardId) async => progress[cardId];

  @override
  Future<void> recordReview({
    required ReviewRecord review,
    required CardProgress progress,
  }) async {
    reviewCount++;
    savedReviews.add(review);
    this.progress[progress.cardId] = progress;
  }

  @override
  Future<LessonSession?> activeSessionForLesson(int lessonId) async => null;

  @override
  Future<List<CardProgress>> dueCards(DateTime through) async => const [];

  @override
  Future<LessonSession?> latestActiveSession() async => null;

  @override
  Future<List<ReviewRecord>> reviewHistory({int? cardId, int? limit}) async =>
      savedReviews
          .where((review) => cardId == null || review.cardId == cardId)
          .take(limit ?? savedReviews.length)
          .toList(growable: false);

  @override
  Future<LessonSession> startSession(int lessonId) =>
      throw UnimplementedError();

  @override
  Future<void> updateSessionPosition({
    required int sessionId,
    required int currentCardIndex,
    required int expectedCardsReviewed,
  }) async {}

  @override
  Future<void> updateSession(
    LessonSession session, {
    bool reconcileFromHistory = false,
    int? expectedCardsReviewed,
    int? expectedCorrectAnswers,
  }) async {}

  @override
  Future<List<VocabularyCardProgress>> vocabularyProgress() async => const [];
}

class _FakeSystemVoiceService extends _FakePronunciationService
    implements SystemVoiceInstaller {
  bool installed = false;
  bool failOpen = false;
  bool failCheck = false;
  int openCalls = 0;

  @override
  Future<OfflineVoiceStatus> checkOfflineVoice() async =>
      const OfflineVoiceStatus.unavailable();

  @override
  Future<bool> isMandarinVoiceInstalled() async {
    if (failCheck) throw StateError('Speech engine unavailable');
    return installed;
  }

  @override
  Future<void> openMandarinVoiceInstaller() async {
    openCalls++;
    if (failOpen) throw StateError('No installer');
  }
}

class _CountingStatsProgress extends _MemoryProgressRepository
    implements ProgressSummaryRepository {
  _CountingStatsProgress() : super(hasActiveSession: false);

  final statisticsDates = <DateTime>[];

  @override
  Future<Map<int, LessonSession>> activeLessonSessions() async => const {};

  @override
  Future<DashboardLearningStats> learningStats(DateTime now) async {
    statisticsDates.add(now);
    return const DashboardLearningStats();
  }
}

class _DeletableLessonRepository extends _MemoryLessonRepository {
  static const generated = LessonSummary(
    id: 91,
    title: 'My generated lesson',
    theme: 'Daily Life',
    hskLevel: 1,
    isUserGenerated: true,
  );
  bool deleted = false;
  int deleteCalls = 0;
  Completer<void> deletion = Completer<void>();

  @override
  Future<List<LessonSummary>> topics() async => [
    if (!deleted) generated,
    lesson.summary,
  ];

  @override
  Future<void> deleteGenerated(int lessonId) async {
    if (lessonId != generated.id) throw StateError('Bundled lesson');
    deleteCalls++;
    await deletion.future;
    deleted = true;
  }
}

final _testVocabularyEntries =
    (jsonDecode(File('assets/data/hsk_vocabulary.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();

class _TestVocabulary extends BundledVocabularyRepository {
  const _TestVocabulary();
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async =>
      _testVocabularyEntries;
}

class _DeferredVocabulary extends BundledVocabularyRepository {
  _DeferredVocabulary(this.result);
  final Completer<List<Map<String, dynamic>>> result;
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) =>
      result.future;
}

class _FailOnceVocabulary extends _TestVocabulary {
  int calls = 0;
  @override
  Future<List<Map<String, dynamic>>> load({AssetBundle? bundle}) async {
    if (++calls == 1) throw StateError('sensitive database path');
    return super.load(bundle: bundle);
  }
}
