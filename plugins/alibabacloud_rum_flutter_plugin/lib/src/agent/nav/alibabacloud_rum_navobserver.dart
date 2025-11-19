import 'package:alibabacloud_rum_flutter_plugin/alibabacloud_rum_flutter_plugin.dart';
import 'package:alibabacloud_rum_flutter_plugin/src/business/alibabacloud_rum_business_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

/// Navigation observer which is reporting routes
class AlibabaCloudRUMNavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  AlibabaCloudRUMBusinessInterface _business;

  AlibabaCloudRUMNavigationObserver() : _business = AlibabaCloudRUMBusinessInterface();
  static const int _MODEL_ENTER = 1;
  static const int _MODEL_EXIT = 2;
  String _preViewId = Uuid().v4();
  String _curViewId = Uuid().v4();
  bool isFirstStart = true;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    String? enterName = _getRouteName(route);
    String? exitName = _getRouteName(previousRoute);
    _reportView(enterName, exitName, "didPush");
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    String? enterName = _getRouteName(previousRoute);
    String? exitName = _getRouteName(route);
    _reportView(enterName, exitName, "didPop");
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    String? enterName = _getRouteName(newRoute);
    String? exitName = _getRouteName(oldRoute);
    _reportView(enterName, exitName, "didReplace");
  }

  void _reportView(String? enterName, String? exitName, String method) {
    try {
      int nowTime = _getTime();
      _preViewId = _curViewId;
      _curViewId = _getId();
      if (!isFirstStart) {
        _business.reportView(nowTime, _preViewId, 0, _MODEL_EXIT, exitName, method);
      }
      isFirstStart = false;
      _business.reportView(nowTime, _curViewId, 0, _MODEL_ENTER, enterName, method);
    } catch (e) {
      print(e);
    }
  }

  String? _getRouteName(Route<dynamic>? route) {
    if (route is AlibabaCloudRUMMaterialPageRoute) {
      return route.routeName;
    }
    if (route is PageRoute) {
      return route.settings.name;
    }
    return null;
  }

  int _getTime() {
    return new DateTime.now().millisecondsSinceEpoch;
  }

  String _getId() {
    return Uuid().v4();
  }
}
