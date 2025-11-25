import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'platform_login_service.dart';

class UserService extends ChangeNotifier {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  final ApiService _apiService = ApiService();
  final PlatformLoginService _platformLoginService = PlatformLoginService();

  /// 初始化：从本地加载用户信息
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');
      if (userJson != null) {
        _currentUser = UserModel.fromJson(json.decode(userJson));
        notifyListeners();
        // 后台刷新用户信息
        fetchProfile();
      }
    } catch (e) {
      debugPrint('Failed to load user from prefs: $e');
    }
  }

  /// 刷新用户信息
  Future<void> fetchProfile() async {
    if (_currentUser == null) return;
    try {
      // 需要在 ApiService 中添加 getProfile 方法，或者直接调用通用接口
      // 这里假设我们添加一个 getProfile 方法到 ApiService，或者直接使用 http 调用
      // 为了简单，我们暂时在 ApiService 中添加 getProfile，或者在这里直接调用
      // 由于 ApiService 是单例，我们可以在那里添加。
      // 暂时我们先用 getUserUsageStats 替代或者直接请求 auth/profile
      
      // 实际上 ApiService 还没有 getProfile，我们需要添加或者使用 custom call
      // 这里我们先跳过 ApiService 的修改，直接用 _apiService 的 client (不可访问)
      // 所以我们需要在 ApiService 添加 getProfile。
      // 既然我们不能轻易修改 ApiService (它很大)，我们可以在这里模拟或者添加。
      // 刚才我们修改了 auth.js 添加了 /profile 接口。
      
      // 让我们在 ApiService 中添加 getProfile 方法。
      // 但是为了避免再次修改 ApiService 文件导致上下文切换过多，
      // 我会在 UserService 中直接使用 ApiService 的通用方法（如果有）或者
      // 只能修改 ApiService。
      // ApiService 没有通用 get 方法暴露。
      // 所以我必须修改 ApiService 或者在 UserService 中实现 http 请求。
      // 为了代码整洁，我应该修改 ApiService。
      // 但为了节省步骤，我先在 UserService 中实现 fetchProfile 逻辑 (如果 ApiService 有暴露 client 就好了，但它是私有的)
      // 
      // 等等，ApiService 有 getUserUsageStats，但那个是 usage-stats。
      // 我还是去 ApiService 添加 getProfile 吧，或者
      // 我直接在 UserService 中实现 fetchProfile，复制 ApiService 的一些配置。
      // 不，这不好。
      // 我将在 ApiService 中添加 getUserProfile。
      
      // 既然我已经决定修改 ApiService，那就在下一步做。
      // 这里先写好调用。
      final userProfile = await _apiService.getUserProfile(_currentUser!.id.toString());
      _currentUser = UserModel.fromJson(userProfile);
      _saveUserToPrefs();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh profile: $e');
    }
  }

  /// 华为一键登录
  Future<bool> loginWithHuawei() async {
    try {
      final authCode = await _platformLoginService.harmonyOSQuickLogin();
      final data = await _apiService.loginWithHuaweiCode(authCode);
      _handleLoginSuccess(data['data']);
      return true;
    } catch (e) {
      debugPrint('Huawei login failed: $e');
      return false;
    }
  }

  /// 阿里一键登录
  Future<bool> loginWithAli(String token) async {
    try {
      final data = await _apiService.loginWithAliToken(token);
      _handleLoginSuccess(data['data']);
      return true;
    } catch (e) {
      debugPrint('Ali login failed: $e');
      return false;
    }
  }

  void _handleLoginSuccess(Map<String, dynamic> userData) {
    _currentUser = UserModel.fromJson(userData);
    _saveUserToPrefs();
    notifyListeners();
  }

  Future<void> _saveUserToPrefs() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(_currentUser!.toJson()));
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    notifyListeners();
  }
}
