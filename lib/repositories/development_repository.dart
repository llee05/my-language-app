abstract interface class DevelopmentRepository {
  Future<String> databasePath();
  Future<void> resetAllData();
}
