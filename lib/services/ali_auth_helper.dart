import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ali_auth/ali_auth.dart';
import '../config/api_keys.dart';
import 'platform_login_service.dart';
import 'api_service.dart';

/// Helper to start AliAuth or HarmonyOS quick login from anywhere in the app.
class AliAuthHelper {
  static final ApiService _apiService = ApiService();

  /// Start login flow. Returns true on success, false on failure or null if cancelled.
  static Future<bool?> startLogin(BuildContext context) async {
    try {
      if (PlatformLoginService.isHarmonyOS) {
        // HarmonyOS native quick login flow
        final authCode = await PlatformLoginService().harmonyOSQuickLogin();
        if (kDebugMode) print('HarmonyOS authCode: $authCode');
        final resp = await _apiService.loginWithHuaweiCode(authCode);
        if (resp['success'] == true) {
          if (mountedContext(context)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('登录成功'), backgroundColor: Colors.green));
          }
          return true;
        }
        if (mountedContext(context)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登录失败: ${resp['message'] ?? resp['error'] ?? 'unknown'}')));
        }
        return false;
      }

      // For Android/iOS use AliAuth
      // Register listener
      Completer<bool?> completer = Completer<bool?>();

      AliAuth.loginListen(onEvent: (event) async {
        final mapEvent = _normalizeEvent(event);
        final code = mapEvent['code']?.toString() ?? '';
        final data = mapEvent['data'];
        if (kDebugMode) print('AliAuth listen event: $mapEvent');

        if (code == '600000') {
          // success
          final parsed = _parseLoginData(data);
          final token = parsed['token'] ?? '';
          try {
            final serverResult = await _apiService.loginWithAliToken(token);
            if (serverResult['success'] == true) {
              if (!completer.isCompleted) completer.complete(true);
              try {
                await AliAuth.quitPage();
              } catch (_) {}
              return;
            }
          } catch (e) {
            if (kDebugMode) print('Server token exchange failed: $e');
          }
          if (!completer.isCompleted) completer.complete(false);
        } else if (code == '700000' || code == '700001') {
          // cancelled
          if (!completer.isCompleted) completer.complete(null);
        }
      });

      // Init SDK with a sane default config
      final config = AliAuthModel(
        ApiKeys.aliAuthAndroidSk,
        ApiKeys.aliAuthIosSk,
        isDebug: kDebugMode,
        autoQuitPage: true,
        pageType: PageType.fullPort,
        // UI customizations requested per plugin docs:
        // Show navigation bar but hide its title text; keep the return/back button visible.
        navHidden: false,
        navText: '',
        navTextColor: '#000000',
        navColor: '#00000000',
        navReturnHidden: false,
        navReturnImgPath: 'assets/back.svg',
        switchAccHidden: true,
        sloganHidden: true,
        numberColor: '#00FFFFFF',
        // login button styles
        logBtnTextColor: '#000000',
        // note: custom background images can be provided via `logBtnBackgroundPath` if you add assets.
        // place the privacy text below the login button (value used in other places: 400)
        logBtnOffsetY: 320,
        privacyOffsetY: 400,
        privacyMargin: 16,
        // keep checkbox visible by default; if you want it hidden, set `checkboxHidden: true`
        // keep existing checkbox images if present
        uncheckedImgPath: 'assets/btn_unchecked.png',
        checkedImgPath: 'assets/btn_checked.png',
      );

      await AliAuth.initSdk(config);
      await AliAuth.login();

      // Wait for result from listener
      return completer.future.timeout(const Duration(seconds: 60), onTimeout: () {
        return false;
      });
    } catch (e) {
      if (kDebugMode) print('startLogin error: $e');
      if (mountedContext(context)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登录异常: $e')));
      }
      return false;
    }
  }

  static bool mountedContext(BuildContext? ctx) {
    // best-effort check
    return ctx != null;
  }

  static Map<String, dynamic> _normalizeEvent(dynamic rawEvent) {
    if (rawEvent is Map) {
      return rawEvent.map((key, value) => MapEntry(key.toString(), value));
    }
    if (rawEvent == null) return {};
    return {'code': rawEvent.toString(), 'msg': rawEvent.toString()};
  }

  static Map<String, String?> _parseLoginData(dynamic data) {
    if (data is Map) {
      final token = data['token']?.toString() ?? '';
      final phone = data['phone']?.toString();
      return {'token': token, 'phone': phone};
    }
    final token = data?.toString() ?? '';
    return {'token': token, 'phone': null};
  }
}
