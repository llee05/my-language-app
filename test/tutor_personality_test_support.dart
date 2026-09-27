import 'package:mylanguageapp/models/tutor_personality.dart';
import 'package:mylanguageapp/repositories/tutor_personality_repository.dart';

class MemoryTutorPersonalityRepository implements TutorPersonalityRepository {
  TutorPersonalityLibrary library = TutorPersonalityLibrary();
  Object? saveError;
  Object? loadError;

  @override
  Future<TutorPersonalityLibrary> load() async {
    if (loadError != null) throw loadError!;
    return library;
  }

  @override
  Future<void> save(TutorPersonalityLibrary value) async {
    if (saveError != null) throw saveError!;
    library = value;
  }
}
