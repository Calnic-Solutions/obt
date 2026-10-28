import 'dart:io';

/// What this phone is called in the server's sign-in and activity logs.
///
/// The Admin dashboard files each sign-in under the device the app
/// reported and reads the platform off that string, so it starts with
/// the operating system by name: "Android 14 (SDK 34)", "iOS 17.4". The
/// app's name and version ride along, since the same account may sign in
/// from the desktop app too.
String deviceLabel({required String appVersion}) {
  final os = switch (Platform.operatingSystem) {
    'android' => 'Android',
    'ios' => 'iOS',
    'windows' => 'Windows',
    'macos' => 'macOS',
    'linux' => 'Linux',
    final other => other,
  };
  final version = Platform.operatingSystemVersion.trim();
  final label = '$os $version - LIVUKA $appVersion';
  // The server keeps 128 characters of it.
  return label.length > 120 ? label.substring(0, 120) : label;
}
