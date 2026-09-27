import 'dart:convert';

/// A teaching style, separate from the tutor's response and learning rules.
class TutorPersonality {
  const TutorPersonality({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
  });

  final String id;
  final String name;
  final String description;
  final String instructions;

  bool get isCustom => id.startsWith('custom_');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'instructions': instructions,
  };

  factory TutorPersonality.fromJson(Map<String, dynamic> json) {
    String read(String key, int limit) {
      final value = json[key];
      if (value is! String ||
          value.trim().isEmpty ||
          value.trim().length > limit) {
        throw FormatException('Invalid personality $key.');
      }
      return value.trim();
    }

    return TutorPersonality(
      id: read('id', 100),
      name: read('name', 60),
      description: read('description', 180),
      instructions: read('instructions', 1500),
    );
  }

  static TutorPersonality fromAiResponse(
    String response, {
    required String id,
  }) {
    if (response.length > 16000) {
      throw const FormatException('Personality response is too long.');
    }
    final decoded = jsonDecode(
      response.trim().replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), ''),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a personality profile.');
    }
    return TutorPersonality.fromJson({...decoded, 'id': id});
  }

  static const builtIns = [
    TutorPersonality(
      id: 'long_laoshi',
      name: '龙老师 - Long Laoshi',
      description:
          'A patient teacher who builds confidence, one small step at a time.',
      instructions:
          'Be a warm, patient Mandarin teacher. Explain simply, gently correct mistakes, and celebrate progress.',
    ),
    TutorPersonality(
      id: 'chatty_friend',
      name: 'Chatty Friend',
      description:
          'Relaxed everyday conversation, with gentle nudges to keep you talking.',
      instructions:
          'Be a friendly conversation partner. Use natural everyday Mandarin, share light fictional anecdotes, and ask one short follow-up question. Correct only the most useful mistake each turn.',
    ),
    TutorPersonality(
      id: 'precision_coach',
      name: 'Precision Coach',
      description:
          'Clear corrections and focused drills for grammar and word choice.',
      instructions:
          'Be an encouraging, precise coach. Point out specific grammar or word-choice mistakes, give a corrected example, then offer one short practice drill. Never shame the learner.',
    ),
    TutorPersonality(
      id: 'travel_guide',
      name: 'Travel Guide',
      description:
          'Practise ordering food, asking directions, and exploring a new city.',
      instructions:
          'Be an upbeat travel guide. Build short practical travel roleplays in Mandarin, including restaurants, transport, and hotels. Introduce useful polite phrases and take one conversational step at a time.',
    ),
    TutorPersonality(
      id: 'storyteller',
      name: 'Storyteller',
      description:
          'Learn through tiny stories where you decide what happens next.',
      instructions:
          'Be an imaginative storyteller. Teach Mandarin with very short, level-appropriate fictional stories. Reuse vocabulary and invite the learner to choose what happens next.',
    ),
    TutorPersonality(
      id: 'culture_companion',
      name: 'Culture Companion',
      description:
          'Explore everyday customs and the meaning behind useful expressions.',
      instructions:
          'Be a curious cultural companion. Connect Mandarin expressions to everyday customs and context. Avoid stereotypes and acknowledge regional differences and uncertainty. Give practical examples.',
    ),
    TutorPersonality(
      id: 'quiz_master',
      name: 'Quiz Master',
      description:
          'Quick challenges, helpful hints, and explanations after each answer.',
      instructions:
          'Be a playful quiz host. Ask one short Mandarin question at a time, wait for the answer, and give a hint before revealing the solution. Explain answers kindly and adapt difficulty to the learner.',
    ),
  ];
}

class TutorPersonalityLibrary {
  TutorPersonalityLibrary({
    this.selectedId = 'long_laoshi',
    List<TutorPersonality> custom = const [],
  }) : custom = List.unmodifiable(custom);

  final String selectedId;
  final List<TutorPersonality> custom;

  List<TutorPersonality> get all => [...TutorPersonality.builtIns, ...custom];
  TutorPersonality get selected => all.firstWhere(
    (personality) => personality.id == selectedId,
    orElse: () => TutorPersonality.builtIns.first,
  );

  Map<String, dynamic> toJson() => {
    'selectedId': selectedId,
    'custom': custom.map((personality) => personality.toJson()).toList(),
  };

  factory TutorPersonalityLibrary.fromJson(Map<String, dynamic> json) {
    final entries = json['custom'];
    if (entries is! List ||
        entries.length > 30 ||
        json['selectedId'] is! String) {
      throw const FormatException('Invalid saved personalities.');
    }
    final custom = <TutorPersonality>[];
    final ids = <String>{};
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid saved personality.');
      }
      final personality = TutorPersonality.fromJson(entry);
      if (!personality.isCustom || !ids.add(personality.id)) {
        throw const FormatException('Invalid custom personality ID.');
      }
      custom.add(personality);
    }
    return TutorPersonalityLibrary(
      selectedId: json['selectedId'] as String,
      custom: custom,
    );
  }
}
