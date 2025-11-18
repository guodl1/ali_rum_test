import 'dart:ui';

import 'package:ali_auth/ali_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/api_keys.dart';

class AliAuthConfig {
  static AliAuthModel buildFullScreenConfig() {
    final view = PlatformDispatcher.instance.views.first;
    final screenHeight =
        (view.physicalSize.height / view.devicePixelRatio).floor();
    final unit = (screenHeight * 0.06).floor();
    final logBtnHeight = (unit * 1.1).floor();

    return AliAuthModel(
      ApiKeys.aliAuthAndroidSk,
      ApiKeys.aliAuthIosSk,
      isDebug: kDebugMode,
      pageType: PageType.fullPort,
      statusBarColor: "#FFFFFF",
      isStatusBarHidden: false,
      navColor: "#FFFFFF",
      navText: "本机号码一键登录",
      navTextColor: "#191919",
      navTextSize: 18,
      navReturnHidden: false,
      numberColor: "#191919",
      numberSize: 26,
      logBtnText: "本机号码一键登录",
      logBtnTextSize: 16,
      logBtnTextColor: "#FFFFFF",
      logBtnOffsetY: logBtnHeight * 2,
      logBtnHeight: logBtnHeight,
      logBtnBackgroundPath: "",
      logoHidden: true,
      privacyState: false,
      protocolOneName: "《用户协议》",
      protocolOneURL: "https://example.com/user-agreement",
      protocolTwoName: "《隐私政策》",
      protocolTwoURL: "https://example.com/privacy",
      protocolCustomColor: "#4CAF50",
      protocolColor: "#9E9E9E",
      protocolLayoutGravity: Gravity.centerHorizntal,
      logBtnToastHidden: false,
      sloganText: "欢迎使用听阅",
      sloganTextColor: "#9E9E9E",
      sloganHidden: false,
      sloganTextSize: 12,
      privacyTextSize: 12,
      privacyBefore: "我已阅读并同意",
      privacyEnd: "",
      switchAccText: "使用其它号码登录",
      switchAccTextColor: "#4CAF50",
      switchAccTextSize: 14,
      screenOrientation: -1,
    );
  }
}

