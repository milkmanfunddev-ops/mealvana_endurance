// Platform utilities for mobile/desktop platforms
import 'dart:io';

class PlatformInfo {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static String get operatingSystem => Platform.operatingSystem;
}
