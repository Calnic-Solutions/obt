import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:http/http.dart' as http;

import 'dataload_controller.dart';
import 'home.dart';
import 'main.dart';
import 'services/activity_log.dart';
import 'services/auto_send.dart';
import 'services/device_label.dart';
import 'services/media_session.dart';
import 'services/services.dart';
import 'services/session.dart';
import 'services/sign_out.dart';
import 'services/user_store.dart';

import 'package:flutter_svg/flutter_svg.dart';

class LoginController extends GetxController {
  final Uri loginUri = MainApp.buildmainUri('auth/login');

  final TextEditingController emailController = TextEditingController(
    // text: 'drafterdemo@obt.calnicsolutions.in',
  ); // Default to empty string for email
  final TextEditingController passwordController = TextEditingController(
    // text: '123456',
  ); // Default to empty string for password

  final RxBool obscurePassword = true.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<Map<String, dynamic>?> userData = Rx<Map<String, dynamic>?>(null);
  String? token;

  @override
  void onInit() {
    super.onInit();
    // Both fields start empty, every time: the phone may be shared, and
    // an address left in the box says who was here last. The saved
    // sign-in still answers an offline attempt once it is typed.
    MediaSession.restore();
  }

  void toggleObscurePassword() {
    obscurePassword.value = !obscurePassword.value;
  }

  /// Signing in with no server to ask.
  ///
  /// Every sign-in is asked for, but only a server can answer a new one.
  /// Out of signal, the phone falls back on the pairs the server has
  /// accepted here before, kept in the keystore since - and the work each
  /// of them downloaded is still in their own folder, so there is nothing
  /// to fetch. Nothing from the server is skipped by this: a server that
  /// can be reached is always asked first.
  Future<void> _signInOffline(String email, String password) async {
    final account = SessionService.accountFor(email);
    if (account == null) {
      errorMessage.value =
          'Cannot reach the OBT server. The first sign-in on this phone '
          'needs a connection - that is when your work is downloaded.';
      return;
    }
    if (!await MediaSession.matches(email: email, password: password)) {
      errorMessage.value =
          'No connection, and this is not the password that signed in '
          'with this email on this phone.';
      return;
    }
    if (!await SessionService.switchTo(email)) {
      errorMessage.value = 'Something went wrong. Please try again.';
      return;
    }
    // A download that was cut off has left this folder part filled, and
    // only the server can finish it.
    if (SessionService.dataLoadInterrupted) {
      errorMessage.value =
          'Your last download did not finish. Connect to the internet and '
          'sign in again to complete it.';
      return;
    }

    await UserStore.use(SessionService.userId);
    debugPrint('LOGIN OFFLINE: user ${SessionService.userId}');
    await ActivityLog.record('signed_in', details: {'offline': true});
    MainApp.roles = SessionService.roles;
    // Nothing to fetch and nothing to prepare: each Set's files are turned
    // back from the vault as its screen opens.
    IdleLogout.instance.start();
    AutoSend.instance.start();
    Get.put(DrafterController());
    Get.offAll(() => const HomePage());
  }

  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    errorMessage.value = '';

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please enter both email and password.';
      return;
    }

    isLoading.value = true;

    try {
      // The server is asked whenever it can be: it is the one that knows
      // whether the password is still right, and the moment the phone
      // catches up on its work. Without it, the sign-in is checked against
      // the one the server last accepted on this phone.
      final wasSignedIn = SessionService.isLoggedIn;
      if (!await canReachServer()) {
        // The probe itself may have found the account shut out, handed the
        // work in and emptied the phone: the sign-in page is already being
        // shown with the reason, and there is nothing to add.
        if (wasSignedIn && !SessionService.isLoggedIn) return;
        await _signInOffline(email, password);
        return;
      }

      final requestBody = jsonEncode({
        'email': email,
        'password': password,
        // Filed under this name in Admin > Offline app sign-ins, which
        // reads the platform off it; the version goes beside it.
        'device_name': deviceLabel(appVersion: MainApp.appVersion),
        'app_version': MainApp.appVersion,
      });

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http
          .post(loginUri, headers: headers, body: requestBody)
          .timeout(const Duration(seconds: 20));

      dynamic bodyData;

      try {
        bodyData = jsonDecode(response.body);
      } catch (e) {
        debugPrint('JSON DECODE ERROR: $e');
        errorMessage.value = 'Invalid server response.';
        return;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          bodyData is Map &&
          bodyData['ok'] == true) {
        token = bodyData['token'] as String?;

        final user = bodyData['user'];

        if (user is Map) {
          userData.value = Map<String, dynamic>.from(user);
        }

        // Who signed in, and nothing that would let anyone else do it for
        // them: the log is readable by whatever else is on the phone, in a
        // released build as much as in a debug one, and a token written
        // there is a key left in the door.
        debugPrint('LOGIN SUCCESS: user ${userData.value?['id']}');

        // Each person who signs in gets a folder of their own on the phone,
        // so whoever was here before keeps their work, and this user sees
        // only theirs. Someone who has signed in here before is a returning
        // user: their folder is filled, and the load only tops it up.
        final newId = userData.value?['id'] ?? userData.value?['UserID'];
        final known = SessionService.accountFor(email);
        final returning = known != null;

        if ((token ?? '').isNotEmpty) {
          await SessionService.save(
            token: token!,
            user: userData.value,
            email: email,
            // Kept: the roles came down with the last data load, and the
            // save would otherwise empty them until the next one.
            roles: [
              for (final role in (known?['roles'] as List? ?? const []))
                role.toString(),
            ],
          );
        }
        await UserStore.use(newId ?? SessionService.userId);
        await ActivityLog.record('signed_in');

        // Source material is served by the web app, which only accepts a
        // browser-style session - so the data load that follows needs these
        // credentials as well as the token.
        await MediaSession.useCredentials(email: email, password: password);

        // The same load either way: it fetches only what the phone does
        // not have, so for a returning user it is the update check, with
        // the same screen saying so.
        IdleLogout.instance.start();
        AutoSend.instance.start();
        Get.put(DrafterController());
        Get.offAll(
          () => const DataLoadingScreen(),
          arguments: DataLoadArguments(userId: newId, firstLoad: !returning),
        );
      } else {
        errorMessage.value = _extractErrorMessage(bodyData);
      }
    } catch (e, stackTrace) {
      debugPrint('SIGN IN ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');

      errorMessage.value = 'Something went wrong. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  String _extractErrorMessage(dynamic body) {
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map &&
          errors['email'] is List &&
          errors['email'].isNotEmpty) {
        return errors['email'].first.toString();
      }
      if (body['message'] != null) {
        return body['message'].toString();
      }
    }
    return 'Sign in failed. Please try again.';
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(LoginController());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The full-colour wordmark above the greeting, as the
                  // website's sign-in form shows it on a phone.
                  SvgPicture.asset(
                    'assets/brand/livuka-wordmark.svg',
                    width: 170,
                    semanticsLabel: 'LIVUKA',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back'.tr,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: MainApp.titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue to your workbench.'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MainApp.mutedText,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Email'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MainApp.titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller.emailController,
                    keyboardType: TextInputType.emailAddress,

                    // An address reads left to right in any language.
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      hintText: 'Enter your email'.tr,
                      prefixIcon: const Icon(Icons.mail_outline, size: 20),
                      filled: true,
                      fillColor: MainApp.fieldFill,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Password'.tr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MainApp.titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => TextField(
                      controller: controller.passwordController,
                      obscureText: controller.obscurePassword.value,
                      decoration: InputDecoration(
                        hintText: 'Enter your password'.tr,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.obscurePassword.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: controller.toggleObscurePassword,
                        ),
                        filled: true,
                        fillColor: MainApp.fieldFill,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // Inline API/validation error
                  Obx(
                    () => controller.errorMessage.value.isEmpty
                        ? const SizedBox(height: 12)
                        : Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              controller.errorMessage.value.tr,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),
                  Obx(
                    () => SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: controller.isLoading.value
                            ? null
                            : controller.signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MainApp.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: controller.isLoading.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.login, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Sign in'.tr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    // Text.rich rather than RichText, which takes nothing
                    // from the theme and was drawn in the platform's font.
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 13,
                          color: MainApp.mutedText,
                        ),
                        children: [
                          TextSpan(
                            text:
                                'Trouble signing in? Contact your project '
                                        'administrator.'
                                    .tr,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
