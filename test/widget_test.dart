import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, SystemChannels, AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mylanguageapp/ai/gemini_service.dart';
import 'package:mylanguageapp/main.dart';
import 'package:mylanguageapp/models/learning_progress.dart';
import 'package:mylanguageapp/models/tutor_learner_snapshot.dart';
import 'package:mylanguageapp/repositories/development_repository.dart';
import 'package:mylanguageapp/repositories/daily_review_session_repository.dart';
import 'package:mylanguageapp/repositories/app_dependencies.dart';
import 'package:mylanguageapp/repositories/bundled_vocabulary_repository.dart';
import 'package:mylanguageapp/repositories/learner_repository.dart';
import 'package:mylanguageapp/repositories/lesson_repository.dart';
import 'package:mylanguageapp/repositories/progress_repository.dart';
import 'package:mylanguageapp/repositories/settings_repository.dart';
import 'package:mylanguageapp/repositories/sqlite_repositories.dart';
import 'package:mylanguageapp/repositories/tutor_context_repository.dart';
import 'package:mylanguageapp/services/pronunciation_service.dart';

import 'ai_test_support.dart';
import 'tutor_personality_test_support.dart';
import 'lesson_guide_test_support.dart';

// Feature case files share these test doubles and retain the original test
// registration order. Keep this entry point for existing focused test commands.
part 'widget_cases/theme_cases.dart';
part 'widget_cases/navigation_cases.dart';
part 'widget_cases/lessons_cases.dart';
part 'widget_cases/dashboard_cases.dart';
part 'widget_cases/legacy_review_cases.dart';
part 'widget_cases/tutor_cases.dart';
part 'widget_cases/settings_reset_cases.dart';
part 'widget_cases/settings_preferences_cases.dart';
part 'widget_cases/helpers.dart';
part 'widget_cases/test_doubles.dart';

const testProfile = LearnerProfile(
  name: 'Mei',
  hskLevel: 2,
  dailyWordTarget: 10,
);

void main() {
  _registerThemeWidgetTests();
  _registerBackNavigationWidgetTests();
  _registerNarrowLessonWidgetTests();
  _registerDashboardRefreshWidgetTests();
  _registerResponsivePageWidgetTests();
  _registerDashboardHomeWidgetTests();
  _registerLegacyQueueWidgetTests();
  _registerDiscoveryRetryWidgetTests();
  _registerLegacyReviewWidgetTests();
  _registerLessonLibraryWidgetTests();
  _registerDashboardLessonWidgetTests();
  _registerLessonSessionWidgetTests();
  _registerTutorWidgetTests();
  _registerMobileNavigationWidgetTests();
  _registerSettingsResetWidgetTests();
  _registerSettingsPreferencesWidgetTests();
  _registerLessonTileWidgetTests();
}
