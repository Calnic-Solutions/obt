import 'package:permission_handler/permission_handler.dart';

/// Asks for the microphone, requesting it only when it can actually be
/// granted.
///
/// The three states matter separately. `denied` is the first-run case and is
/// worth prompting for. `permanentlyDenied` cannot be prompted again at all —
/// the system dialog never appears a second time — so the only way back is
/// the app's settings page, which is what [openMicrophoneSettings] is for.
/// Calling `request()` on that state just returns false, which is what makes
/// a record button look broken.
Future<bool> checkMicrophonePermission() async {
  var status = await Permission.microphone.status;

  if (status.isDenied) {
    status = await Permission.microphone.request();
  }

  return status.isGranted;
}

/// True once the system will no longer show the prompt, so the user has to be
/// sent to settings instead of asked again.
Future<bool> isMicrophoneBlocked() async {
  final status = await Permission.microphone.status;
  return status.isPermanentlyDenied || status.isRestricted;
}

Future<void> openMicrophoneSettings() => openAppSettings();
