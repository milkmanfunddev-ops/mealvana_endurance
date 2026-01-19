import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Mock path provider for testing.
///
/// Returns a temporary directory path for all path provider methods.
/// This allows tests to create and clean up files without affecting
/// the real file system.
class MockPathProvider extends PathProviderPlatform {
  final String tempDirPath;

  MockPathProvider(this.tempDirPath);

  @override
  Future<String?> getApplicationSupportPath() async {
    return tempDirPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDirPath;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return tempDirPath;
  }

  @override
  Future<String?> getLibraryPath() async {
    return tempDirPath;
  }

  @override
  Future<String?> getApplicationCachePath() async {
    return tempDirPath;
  }

  @override
  Future<String?> getDownloadsPath() async {
    return tempDirPath;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return [tempDirPath];
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return tempDirPath;
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return [tempDirPath];
  }
}
