// ignore_for_file: close_sinks

import 'dart:io';
import 'dart:math';
import 'package:alibabacloud_rum_flutter_plugin/src/agent/http/alibabacloud_rum_http_tool.dart';

import '../../business/alibabacloud_rum_business_interface.dart';
import 'alibabacloud_rum_http_request.dart';

class AlibabaCloudRUMHttpClient implements HttpClient {
  HttpClient _httpClient;
  AlibabaCloudRUMBusinessInterface _business;

  AlibabaCloudRUMHttpClient(this._httpClient, this._business);

  Future<HttpClientRequest> _wrapRequest(Future<HttpClientRequest> Function() httpClientRequest, String urlStr) async {
    String requestkey = new DateTime.now().microsecondsSinceEpoch.toString() + new Random().nextInt(1000).toString();
    try {
      _business.startWebRequest(requestkey, urlStr);
      HttpClientRequest request = await httpClientRequest();
      _addTraceHeader(request);
      _business.endWebRequest(requestkey, request.method, request.headers, request.uri.toString());
      return Future.value(AlibabaCloudRUMHttpRequest(request, _business, requestkey));
    } catch (error) {
      _business.finishWebRequset(requestkey, error.toString());
      throw error;
    }
  }

  void _addTraceHeader(HttpClientRequest request) {
    AlibabaCloudRUMHttpTool.insertKeyInRequest(request);
  }

  @override
  void close({bool force = false}) => _httpClient.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.delete(host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) =>
      _wrapRequest(() async => await _httpClient.deleteUrl(url), url.toString());

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _wrapRequest(() async => await _httpClient.getUrl(url), url.toString());

  @override
  Future<HttpClientRequest> head(String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.head(host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  @override
  Future<HttpClientRequest> headUrl(Uri url) =>
      _wrapRequest(() async => await _httpClient.headUrl(url), url.toString());

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.open(method, host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _wrapRequest(() async => await _httpClient.openUrl(method, url), url.toString());

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.patch(host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  @override
  Future<HttpClientRequest> patchUrl(Uri url) =>
      _wrapRequest(() async => await _httpClient.patchUrl(url), url.toString());

  @override
  Future<HttpClientRequest> post(String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.post(host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  @override
  Future<HttpClientRequest> postUrl(Uri url) =>
      _wrapRequest(() async => await _httpClient.postUrl(url), url.toString());

  @override
  Future<HttpClientRequest> put(String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.put(host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _wrapRequest(() async => await _httpClient.putUrl(url), url.toString());

  @override
  Future<HttpClientRequest> get(String host, int port, String path) => _wrapRequest(
      () async => await _httpClient.get(host, port, path),
      Uri(scheme: "http", host: host, port: port, path: path).toString());

  // NOT USED FUNCTIONS

  @override
  bool get autoUncompress => _httpClient.autoUncompress;

  @override
  set autoUncompress(bool value) => _httpClient.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _httpClient.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _httpClient.connectionTimeout = value;

  @override
  Duration get idleTimeout => _httpClient.idleTimeout;

  @override
  set idleTimeout(Duration value) => _httpClient.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _httpClient.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) => _httpClient.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _httpClient.userAgent;

  @override
  set userAgent(String? value) => _httpClient.userAgent = value;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _httpClient.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _httpClient.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) => _httpClient.authenticate = f;

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) =>
      _httpClient.authenticateProxy = f;

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _httpClient.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => _httpClient.findProxy = f;

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) =>
      _httpClient.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _httpClient.keyLog = callback;
}
