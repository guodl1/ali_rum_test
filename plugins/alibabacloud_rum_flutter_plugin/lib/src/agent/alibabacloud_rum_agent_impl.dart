import 'dart:async';
import 'dart:io';

import 'package:alibabacloud_rum_flutter_plugin/src/business/alibabacloud_rum_method_channel.dart';
import 'package:alibabacloud_rum_flutter_plugin/src/business/util/logger.dart';
import 'package:flutter/cupertino.dart';

import '../business/alibabacloud_rum_business_interface.dart';
import 'http/alibabacloud_rum_http_overrides.dart';
import 'http/alibabacloud_rum_http_tool.dart';
import 'interface/alibabacloud_rum_agent_interface.dart';
import 'http/alibabacloud_rum_http_trace_model.dart';

class AlibabaCloudRUMImpl implements AlibabaCloudRUM {
  static AlibabaCloudRUM? _instance;
  final AlibabaCloudRUMBusinessInterface _business;
  Function? _errorCallback;
  AlibabaCloudRUMHttpTraceConfigModel? traceConfigModel;
  bool isNetworkTraceEnabled = false;
  bool _dumpError = true;

  ///plugin是否启动
  bool _started = false;

  factory AlibabaCloudRUMImpl() {
    if (_instance == null) {
      _instance = AlibabaCloudRUMImpl.private(AlibabaCloudRUMBusinessInterface());
    }
    return _instance as AlibabaCloudRUMImpl;
  }

  AlibabaCloudRUMImpl.private(this._business);

  Future<void> start(Widget topLevelWidget, {Function()? beforeRunApp}) async {
    // If our plugin fails to intialize, allow the app to run like normal
    await runZonedGuarded<Future<void>>(() async {
      await _start(topLevelWidget, beforeRunApp: beforeRunApp);
    }, AlibabaCloudRUMImpl().reportZoneStacktrace);
  }

  Future<void> _start(Widget topLevelWidget, {Function()? beforeRunApp}) async {
    try {
      if (isStarted()) {
        Logger().i("alibabacloud_rum_flutter_plugin is already started.");
        return;
      }
      _started = true;

      var originError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) async {
        if (null != _errorCallback && !_errorCallback?.call(details.exception, details.stack, false)) {
          return;
        }

        if (_dumpError) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
        }

        String errorName = details.exception.runtimeType.toString();
        String reason = "${details.exceptionAsString()} - ${details.toStringShort()}".substring(errorName.length + 2);
        if (originError != null) {
          originError(details);
        }
        await _business.reportCrash(errorName, reason, details.stack.toString());
      };

      //网络
      HttpOverrides.global = new AlibabaCloudRUMHttpOverrides(_business, HttpOverrides.current);

      if (null != beforeRunApp) {
        Logger().i("alibabacloud_rum_flutter_plugin. beforeRunApp is not null.");
        await beforeRunApp();
        Logger().i("alibabacloud_rum_flutter_plugin. beforeRunApp is called.");
      } else {
        //开启崩溃回调监听
        WidgetsFlutterBinding.ensureInitialized();
      }
      runApp(topLevelWidget);

      // 更新网络Trace配置
      Object? config = await MethodChannelContainer().methodChannel.invokeMapMethod("getNetworkTraceConfig");
      updateNetworkTraceConfig(config);
      MethodChannelContainer().methodChannel.setMethodCallHandler((call) async {
        //客户端调用回来
        if (call.method == "setNetworkTraceConfig") {
          updateNetworkTraceConfig(call.arguments);
        }
        return Future.value("nonullStr");
      });
      Logger().i("alibabacloud_rum_flutter_plugin start success");
    } catch (e) {
      Logger().e("alibabacloud_rum_flutter_plugin start failed. error: $e");
    }
  }

  Future<void> reportZoneStacktrace(dynamic error, StackTrace stacktrace, {Platform? platform}) async {
    if (null == error) {
      return;
    }

    if (null != _errorCallback && !_errorCallback?.call(error, stacktrace, true)) {
      return;
    }

    await _business.reportCrash(error.runtimeType.toString(), error.toString(), stacktrace.toString());
  }

  static void updateNetworkTraceConfig(Object? config) {
    //清缓存
    clearNetworkTraceConfig();
    if (config == null) {
      Logger().i("updateNetworkTraceConfig. config is null.");
      return;
    }

    if (config is Map) {
      Logger().i("updateNetworkTraceConfig. config map: ${config}");

      AlibabaCloudRUMImpl().isNetworkTraceEnabled = config["enableNetworkTrace"] ?? false;

      Map? traceMap = config["networkTraceConfig"];
      if (traceMap is Map) {
        Map<String, dynamic>? traceMapChange = Map<String, dynamic>.from(traceMap);
        AlibabaCloudRUMImpl().traceConfigModel = AlibabaCloudRUMHttpTraceConfigModel.fromJson(traceMapChange);
      } else {
        Logger().i("updateNetworkTraceConfig. networkTraceConfig is not map: ${traceMap}");
      }
    } else {
      Logger().i("updateNetworkTraceConfig. config is not Map.");
    }
  }

  static void clearNetworkTraceConfig() {
    AlibabaCloudRUMHttpTool.clearnTraceInsertCache();
    AlibabaCloudRUMImpl().isNetworkTraceEnabled = false;
    AlibabaCloudRUMImpl().traceConfigModel = null;
  }

  bool isStarted() {
    return _started;
  }

  void onRUMErrorCallback(bool callback(Object error, StackTrace stack, bool isAsync)) {
    this._errorCallback = callback;
  }

  void setDumpError(bool enable) {
    this._dumpError = enable;
  }

  /// 设置用户ID
  Future<void> setUserName(String userID) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("setUserID", <String, dynamic>{"userID": userID});
    }
  }

  /// 设置用户附加信息
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> setUserExtraInfo(Map<String, dynamic> extraInfo) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("setUserExtraInfo", extraInfo);
    }
  }

  /// 追加用户附加信息
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> addUserExtraInfo(Map<String, dynamic> extraInfo) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("addUserExtraInfo", extraInfo);
    }
  }

  /// 设置全局附加信息
  Future<void> setExtraInfo(Map<String, dynamic> extraInfo) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("setExtraInfo", extraInfo);
    }
  }

  /// 追加全局扩展属性
  /// @param extraInfo 附加信息为Key-Value形式
  Future<void> addExtraInfo(Map<String, dynamic> extraInfo) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("addExtraInfo", extraInfo);
    }
  }

  Future<void> setCustomException(String exceptionType, String causedBy, String errorDump) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("setCustomException",
          <String, dynamic>{"exceptionType": exceptionType, "causedBy": causedBy, "errorDump": errorDump});
    }
  }

  Future<void> setCustomEvent(String name,
      {String? group, String? snapshots, double? value, Map<String, String>? attributes}) async {
    if (isStarted()) {
      if (name.isEmpty) {
        return;
      }

      await MethodChannelContainer().onMethodChannelInvoke("setCustomEvent", <String, dynamic>{
        "name": name,
        "group": group,
        "snapshots": snapshots,
        "value": value,
        "attributes": attributes
      });
    }
  }

  Future<void> setCustomLog(String logInfo,
      {String? name, String? snapshots, String? level, Map<String, String>? attributes}) async {
    if (isStarted()) {
      if (logInfo.isEmpty) {
        return;
      }

      await MethodChannelContainer().onMethodChannelInvoke("setCustomLog", <String, dynamic>{
        "logInfo": logInfo,
        "name": name,
        "snapshots": snapshots,
        "level": level,
        "attributes": attributes
      });
    }
  }

  Future<void> setCustomMetric(String metricName, int metricValue, String snapshots) async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("setCustomMetric",
          <String, dynamic>{"metricName": metricName, "param": snapshots, "metricValue": metricValue});
    }
  }

  Future<String?> getDeviceId() async {
    if (isStarted()) {
      return await MethodChannelContainer().methodChannel.invokeMethod("getDeviceId");
    }
    return null;
  }

  Future<void> triggerCrash() async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("triggerCrash");
    }
  }

  Future<void> triggerCrash2() async {
    if (isStarted()) {
      await MethodChannelContainer().onMethodChannelInvoke("triggerCrash2");
    }
  }
}
