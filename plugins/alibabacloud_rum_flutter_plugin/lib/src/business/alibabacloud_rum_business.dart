import 'dart:io';

import 'package:alibabacloud_rum_flutter_plugin/src/agent/alibabacloud_rum_agent_impl.dart';
import 'package:alibabacloud_rum_flutter_plugin/src/business/alibabacloud_rum_method_channel.dart';
import 'package:alibabacloud_rum_flutter_plugin/src/business/util/logger.dart';

import 'alibabacloud_rum_business_interface.dart';
import 'model/alibabacloud_rum_network_model.dart';

class AlibabaCloudRUMBusiness implements AlibabaCloudRUMBusinessInterface {
  static AlibabaCloudRUMBusinessInterface? _instance;
  final Map<String, AlibabaCloudRUMNetworkModel> _networkModelMap;

  factory AlibabaCloudRUMBusiness() {
    if (_instance == null) {
      _instance = AlibabaCloudRUMBusiness.private(new Map());
    }
    return _instance as AlibabaCloudRUMBusiness;
  }

  AlibabaCloudRUMBusiness.private(this._networkModelMap);

  bool _isStarted() {
    return AlibabaCloudRUMImpl().isStarted();
  }

  //崩溃回调
  Future<void> reportCrash(String errorName, String reason, String stacktrace) async {
    //获取当前时间戳
    int nowTime = new DateTime.now().millisecondsSinceEpoch;
    await MethodChannelContainer().onMethodChannelInvoke("reportCrash",
        <String, dynamic>{"time": nowTime, "errorValue": errorName, "reason": reason, "stacktrace": stacktrace});
  }

  void startWebRequest(String requestKey, String url) {
    AlibabaCloudRUMNetworkModel model = new AlibabaCloudRUMNetworkModel();
    model.setRequestUrl = url;
    model.setStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    _networkModelMap[requestKey] = model;
  }

  void endWebRequest(String requestKey, String requestMethod, HttpHeaders requestHeader, String? requestUrl) {
    int nowTime = new DateTime.now().millisecondsSinceEpoch;
    AlibabaCloudRUMNetworkModel? model = _networkModelMap[requestKey];
    if (model != null) {
      model.setMethod = requestMethod;
      if (nowTime > model.startTimeMs) model.setConnectTimeMs = nowTime - model.startTimeMs;

      Map header = new Map();
      requestHeader.forEach((name, values) {
        header[name] = values.join(",");
      });
      model.setHttpRequestHeader = header;
      if (requestUrl != null) model.setRequestUrl = requestUrl;
    }
  }

  void startWebResposne(String requestKey, HttpHeaders requestHeader) {
    int nowTime = new DateTime.now().millisecondsSinceEpoch;
    AlibabaCloudRUMNetworkModel? model = _networkModelMap[requestKey];
    if (model != null) {
      model.setResponseStartTimeMs = nowTime;
      Map header = new Map();
      requestHeader.forEach((name, values) {
        header[name] = values.join(",");
      });
      model.setHttpRequestHeader = header;
    }
  }

  void endWebResponse(String requestKey, int errorCode, int responseDataSize, HttpHeaders responseHeader) {
    int nowTime = new DateTime.now().millisecondsSinceEpoch;
    AlibabaCloudRUMNetworkModel? model = _networkModelMap[requestKey];
    if (model != null) {
      model.setErrorCode = errorCode;
      model.setResponseDataSize = responseDataSize;

      Map header = new Map();
      try {
        responseHeader.forEach((name, values) {
          header[name] = values.join(",");
        });
      } catch (e) {
        // Handle potential null pointer or invalid headers
        Logger().e("Error processing response headers: $e");
      }
      model.setHttpResponseHeader = header;

      // Safely handle contentType which may be null
      try {
        String? contentType = responseHeader.contentType?.toString();
        model.setResourceType = contentType ?? '';
      } catch (e) {
        // Handle potential null pointer when accessing contentType
        Logger().e("Error accessing response contentType: $e");
        model.setResourceType = '';
      }

      if (nowTime > model.responseStartTimeMs) model.setResponseTimeMs = nowTime - model.responseStartTimeMs;
    }
  }

  void finishWebRequset(String requestKey, String? errorMsg) {
    AlibabaCloudRUMNetworkModel? model = _networkModelMap[requestKey];
    //上报网络数据
    if (model != null) {
      model.setErrorMessage = errorMsg;
      reportNetwork(model, requestKey);
    }
  }

  Future<void> reportNetwork(AlibabaCloudRUMNetworkModel networkModel, String requestKey) async {
    //获取当前时间戳
    await MethodChannelContainer().onMethodChannelInvoke("reportNetwork", networkModel.toJson());
    _networkModelMap.remove(requestKey);
  }

  @override
  void reportView(int time, String viewId, int loadTime, int model, String? name, String method) async {
    if (!_isStarted()) {
      Logger().i("OpenRUM().start() method was not called!");
      return;
    }
    Logger().i("reportView time:$time, viewId:$viewId, loadTime:$loadTime, model:$model, name:$name, method:$method");
    await MethodChannelContainer().onMethodChannelInvoke("reportView",
        {"time": time, "viewId": viewId, "loadTime": loadTime, "model": model, "name": name, "method": method});
  }
}
