part of '../../main.dart';

String _flashcardDeckTitle(LessonSummary summary) {
  if (summary.isSentencePractice) return summary.theme;
  if (summary.isUserGenerated) return summary.title;
  return summary.title.replaceAll(RegExp(r'\bLesson\b'), 'Deck');
}

List<LessonSummary> _flashcardDecksForMode(
  List<LessonSummary> topics,
  bool sentenceMode,
) {
  final decks = topics
      .where((topic) => topic.isSentencePractice == sentenceMode)
      .toList(growable: false);
  if (sentenceMode) decks.sort((a, b) => a.id.compareTo(b.id));
  return decks;
}

List<LessonSummary> _filterFlashcardDecks(
  List<LessonSummary> topics, {
  required bool sentenceMode,
  required int? hskFilter,
  required String query,
  Map<int, List<Flashcard>> cardsByLesson = const {},
}) {
  query = query.trim().toLowerCase();
  final pinyinQuery = _normalizePinyin(query);
  final compactQuery = pinyinQuery.replaceAll(' ', '');
  return _flashcardDecksForMode(topics, sentenceMode)
      .where((topic) {
        if (!sentenceMode && hskFilter != null && topic.hskLevel != hskFilter) {
          return false;
        }
        if (query.isEmpty) return true;
        if (_flashcardDeckTitle(topic).toLowerCase().contains(query) ||
            topic.title.toLowerCase().contains(query) ||
            topic.theme.toLowerCase().contains(query) ||
            (!sentenceMode &&
                ('hsk ${topic.hskLevel}'.contains(query) ||
                    topic.hskLevel.toString() == query))) {
          return true;
        }
        return (cardsByLesson[topic.id] ?? const []).any((card) {
          final pinyin = _normalizePinyin(card.pinyin);
          return card.chinese.toLowerCase().contains(query) ||
              card.englishMeaning.toLowerCase().contains(query) ||
              (pinyinQuery.isNotEmpty &&
                  (pinyin.contains(pinyinQuery) ||
                      pinyin.replaceAll(' ', '').contains(compactQuery)));
        });
      })
      .toList(growable: false);
}

class _FlashcardLibrary extends StatelessWidget {
  const _FlashcardLibrary({
    required this.topics,
    required this.sentenceMode,
    required this.searchController,
    required this.hskFilter,
    required this.onModeChanged,
    required this.onLevelChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onShowAll,
    required this.loading,
    required this.loadFailed,
    required this.learningProgress,
    required this.onOpen,
    required this.onRetry,
    this.onDelete,
    this.activeLessonIds = const {},
    this.busyLessonIds = const {},
    this.cardsByLesson = const {},
    this.listening = false,
    this.enabled = true,
    this.actions,
  });

  final List<LessonSummary> topics;
  final bool sentenceMode;
  final TextEditingController searchController;
  final int? hskFilter;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<int?> onLevelChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onShowAll;
  final bool loading;
  final bool loadFailed;
  final Map<int, LessonLearningProgress> learningProgress;
  final ValueChanged<LessonSummary> onOpen;
  final VoidCallback onRetry;
  final ValueChanged<LessonSummary>? onDelete;
  final Set<int> activeLessonIds;
  final Set<int> busyLessonIds;
  final Map<int, List<Flashcard>> cardsByLesson;
  final bool listening;
  final bool enabled;
  final Widget? actions;

  String get keyPrefix => listening ? 'listening-library' : 'lesson-library';
  List<LessonSummary> get modeTopics =>
      _flashcardDecksForMode(topics, sentenceMode);
  List<LessonSummary> get visibleTopics => _filterFlashcardDecks(
    topics,
    sentenceMode: sentenceMode,
    hskFilter: hskFilter,
    query: searchController.text,
    cardsByLesson: cardsByLesson,
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppPageHeader(
              title: listening ? 'Listening practice' : 'Flashcards',
              hanzi: listening ? '听力练习' : '词卡',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in [false, true])
                  ChoiceChip(
                    key: Key(
                      mode
                          ? 'sentence-practice-mode'
                          : 'vocabulary-lesson-mode',
                    ),
                    label: Text(mode ? 'Sentence practice' : 'Vocabulary'),
                    selected: sentenceMode == mode,
                    onSelected: enabled ? (_) => onModeChanged(mode) : null,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              sentenceMode
                  ? '100 everyday Mandarin sentences · 10 short decks'
                  : 'HSK 1–6 · 20 words per bundled deck',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              listening
                  ? 'Choose a Flashcards deck, listen to each prompt, and pick its '
                        'English meaning. Hanzi and pinyin appear after you answer.'
                  : sentenceMode
                  ? 'Practice common conversations offline. Tap a card for pinyin '
                        'and English, then rate how well you remember it.'
                  : 'Decks are numbered within each HSK level. Study offline with Tatoeba '
                        'examples and original sentences where needed.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            if (!loading && !loadFailed && actions != null) ...[
              actions!,
              const SizedBox(height: 20),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _buildLessonLibrary(),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildLessonLibrary() {
    if (loading) {
      return _LessonLibraryStateCard(
        key: Key('$keyPrefix-loading-state'),
        accent: AppColors.red,
        icon: SizedBox.square(
          dimension: 25,
          child: CircularProgressIndicator(
            color: AppColors.red,
            strokeWidth: 2.5,
            semanticsLabel: 'Loading saved decks',
          ),
        ),
        title: 'Loading your flashcard library',
        message: 'Finding your saved decks and current progress.',
      );
    }
    if (loadFailed) {
      return _AppErrorState(
        key: Key('$keyPrefix-error-state'),
        title: _AppErrorCopy.lessonsTitle,
        message: _AppErrorCopy.lessonsMessage,
        onRetry: onRetry,
        retryKey: Key('$keyPrefix-retry'),
      );
    }
    if (this.modeTopics.isEmpty) {
      return _LessonLibraryStateCard(
        key: Key('$keyPrefix-empty-state'),
        accent: AppColors.teal,
        icon: Icon(Icons.menu_book_outlined, size: 30, color: AppColors.teal),
        title: sentenceMode
            ? 'No sentence decks available'
            : 'No saved decks yet',
        message: sentenceMode
            ? 'Reopen Flashcards after restoring your bundled content.'
            : 'Reopen Flashcards to load the bundled vocabulary library.',
      );
    }

    final visibleTopics = this.visibleTopics;
    final modeTopics = this.modeTopics;
    final noun = sentenceMode ? 'sentence deck' : 'vocabulary deck';
    final count = visibleTopics.length == modeTopics.length
        ? '${modeTopics.length}'
        : '${visibleTopics.length} of ${modeTopics.length}';
    return Column(
      key: Key('$keyPrefix-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              '$count $noun${modeTopics.length == 1 ? '' : 's'}',
              key: Key('$keyPrefix-count'),
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((!sentenceMode && hskFilter != null) ||
                searchController.text.trim().isNotEmpty)
              TextButton(
                key: Key('$keyPrefix-show-all'),
                onPressed: enabled ? onShowAll : null,
                child: const Text('Show all decks'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: Key('$keyPrefix-search'),
          controller: searchController,
          enabled: enabled,
          onChanged: (_) => onSearchChanged(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: listening
                ? 'Search decks, Hanzi, pinyin, or English'
                : sentenceMode
                ? 'Search sentence topics'
                : 'Search deck titles, topics, or HSK levels',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    key: Key('$keyPrefix-search-clear'),
                    tooltip: 'Clear search',
                    onPressed: enabled ? onClearSearch : null,
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.outline),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (!sentenceMode)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            key: Key('$keyPrefix-level-filter'),
            child: Row(
              children: [
                _LevelChip(
                  label: 'All levels',
                  selected: hskFilter == null,
                  onSelected: enabled ? () => onLevelChanged(null) : null,
                ),
                for (var level = 1; level <= 6; level++) ...[
                  const SizedBox(width: 8),
                  _LevelChip(
                    label: 'HSK $level',
                    selected: hskFilter == level,
                    onSelected: enabled ? () => onLevelChanged(level) : null,
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (visibleTopics.isEmpty && searchController.text.trim().isNotEmpty)
          _LessonLibraryStateCard(
            key: Key('$keyPrefix-search-empty-state'),
            accent: AppColors.teal,
            icon: Icon(Icons.search_off, size: 30, color: AppColors.teal),
            title: 'No decks found',
            message:
                'Try another deck title, topic, or HSK level, or clear the '
                'current level filter.',
          )
        else if (visibleTopics.isEmpty)
          _LessonLibraryStateCard(
            key: Key('$keyPrefix-filtered-empty-state'),
            accent: AppColors.teal,
            icon: Icon(
              Icons.filter_alt_outlined,
              size: 30,
              color: AppColors.teal,
            ),
            title: 'No HSK $hskFilter decks yet',
            message:
                'No saved decks match this level. Select All levels to '
                'return to the full library.',
          )
        else
          for (final (index, topic) in visibleTopics.indexed) ...[
            _LessonLibraryCard(
              key: ValueKey('$keyPrefix-deck-${topic.id}'),
              summary: topic,
              showDelete: onDelete != null,
              actionLabel: listening ? 'Listen' : null,
              actionKey: listening ? Key('listening-start-${topic.id}') : null,
              icon: listening ? Icons.headphones_rounded : Icons.style_outlined,
              learningProgress: learningProgress[topic.id],
              isActive: activeLessonIds.contains(topic.id),
              onPressed: !enabled || busyLessonIds.contains(topic.id)
                  ? null
                  : () => onOpen(topic),
              onDelete:
                  onDelete != null &&
                      topic.isUserGenerated &&
                      !busyLessonIds.contains(topic.id)
                  ? () => onDelete!(topic)
                  : null,
            ),
            if (index != visibleTopics.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _LessonLibraryStateCard extends StatelessWidget {
  const _LessonLibraryStateCard({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color accent;
  final Widget icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: accent.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LessonLibraryCard extends StatelessWidget {
  const _LessonLibraryCard({
    super.key,
    this.actionLabel,
    this.actionKey,
    this.showDelete = true,
    this.icon = Icons.style_outlined,
    required this.summary,
    required this.isActive,
    required this.onPressed,
    this.learningProgress,
    this.onDelete,
  });

  final String? actionLabel;
  final Key? actionKey;
  final bool showDelete;
  final IconData icon;
  final LessonSummary summary;
  final LessonLearningProgress? learningProgress;
  final bool isActive;
  final VoidCallback? onPressed;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final icon = Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(this.icon, color: AppColors.red),
            );
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _flashcardDeckTitle(summary),
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.isSentencePractice
                      ? '10 sentences · Everyday Mandarin'
                      : '${summary.theme} · HSK ${summary.hskLevel}',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (learningProgress case final progress?) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${progress.learnedCards} of ${progress.totalCards} '
                    '${summary.isSentencePractice ? 'sentences' : 'words'} learned',
                    key: Key('lesson-learned-count-${summary.id}'),
                    style: TextStyle(fontSize: 12, color: AppColors.teal),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.fraction,
                    semanticsLabel: 'Learned progress for ${summary.title}',
                    color: AppColors.teal,
                    backgroundColor: AppColors.surfaceLight,
                  ),
                ],
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (summary.isUserGenerated && showDelete)
                  IconButton(
                    key: Key('delete-lesson-${summary.id}'),
                    tooltip: 'Delete deck',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                FilledButton(
                  key: actionKey,
                  onPressed: onPressed,
                  child: Text(actionLabel ?? (isActive ? 'Resume' : 'Start')),
                ),
              ],
            );
            final compact = constraints.maxWidth < 380;
            final heading = Row(
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(child: details),
                if (!compact) ...[const SizedBox(width: 8), actions],
              ],
            );
            if (!compact) return heading;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          },
        ),
      ),
    ),
  );
}
