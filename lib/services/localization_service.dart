import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地化服务
/// 管理应用的多语言切换
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  static const String _localeKey = 'app_locale';
  Locale _currentLocale = const Locale('zh', 'CN');
  Map<String, dynamic> _localizedStrings = {};

  /// 获取当前语言
  Locale get currentLocale => _currentLocale;

  /// 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'), // 中文
    Locale('en', 'US'), // 英文
  ];

  /// 初始化
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey);
    
    if (languageCode != null) {
      _currentLocale = Locale(languageCode);
    }
    
    await _loadLocalizedStrings(_currentLocale);
  }

  /// 加载语言文件
  Future<void> _loadLocalizedStrings(Locale locale) async {
    final String fileName = locale.languageCode == 'zh' ? 'zh.json' : 'en.json';
    final String jsonString = await rootBundle.loadString('lib/localization/$fileName');
    _localizedStrings = json.decode(jsonString);
  }

  /// 切换语言
  Future<void> changeLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    
    _currentLocale = locale;
    await _loadLocalizedStrings(locale);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  /// 获取翻译文本
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  /// 操作符重载，简化调用
  String operator [](String key) => translate(key);
}

/// AppLocalizations 类
/// 用于 MaterialApp 的 localizationsDelegates
class AppLocalizations {
  final Locale locale;
  final LocalizationService _localizationService = LocalizationService();

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String translate(String key) {
    return _localizationService.translate(key);
  }

  String operator [](String key) => translate(key);
}

/// AppLocalizationsDelegate
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return LocalizationService.supportedLocales
        .map((l) => l.languageCode)
        .contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await LocalizationService().init();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
