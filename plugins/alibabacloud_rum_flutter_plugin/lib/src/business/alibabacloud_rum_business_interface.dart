import 'dart:io';
import 'alibabacloud_rum_business.dart';

abstract class AlibabaCloudRUMBusinessInterface {
  //factory
  factory AlibabaCloudRUMBusinessInterface() => AlibabaCloudRUMBusiness();

  ///崩溃事件
  Future<void> reportCrash(String errorName, String reason, String stacktrace);

  //视图跳转
  void reportView(int time, String viewId, int loadTime, int model, String? name, String method);

  //开始网络监控
  void startWebRequest(String requestKey, String url);

  //结束网络请求部分
  void endWebRequest(String requestKey, String requestMethod, HttpHeaders requestHeader, String? requestUrl);

  //开始响应
  void startWebResposne(String requestKey, HttpHeaders requestHeader);

  //结束网络响应
  void endWebResponse(String requestKey, int errorCode, int responseDataSize, HttpHeaders responseHeader);

  //结束网络请求
  void finishWebRequset(String requestKey, String? errorMsg);
}
