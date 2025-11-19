import 'dart:convert';
import 'dart:io';

import '../../business/alibabacloud_rum_business_interface.dart';

class AlibabaCloudRUMHttpRequest implements HttpClientRequest {
  HttpClientRequest _httpClientRequest;
  AlibabaCloudRUMBusinessInterface _business;
  String _requesetId;

  AlibabaCloudRUMHttpRequest(this._httpClientRequest, this._business, this._requesetId);

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _httpClientRequest.addError(exception ?? Exception('request aborted.'), stackTrace);
  }

  @override
  bool get bufferOutput => _httpClientRequest.bufferOutput;

  @override
  set bufferOutput(bool value) => _httpClientRequest.bufferOutput = value;

  @override
  int get contentLength => _httpClientRequest.contentLength;

  @override
  set contentLength(int value) => _httpClientRequest.contentLength = value;

  @override
  Encoding get encoding => _httpClientRequest.encoding;

  @override
  set encoding(Encoding value) => _httpClientRequest.encoding = value;

  @override
  bool get followRedirects => _httpClientRequest.followRedirects;

  @override
  set followRedirects(bool value) => _httpClientRequest.followRedirects = value;

  @override
  int get maxRedirects => _httpClientRequest.maxRedirects;

  @override
  set maxRedirects(int value) => _httpClientRequest.maxRedirects = value;

  @override
  bool get persistentConnection => _httpClientRequest.persistentConnection;

  @override
  set persistentConnection(bool value) => _httpClientRequest.persistentConnection = value;

  @override
  void add(List<int> data) => _httpClientRequest.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _httpClientRequest.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => _httpClientRequest.addStream(stream);

  @override
  Future<HttpClientResponse> close() async {
    try {
      _business.startWebResposne(_requesetId, _httpClientRequest.headers);
      HttpClientResponse response = await _httpClientRequest.close();

      // Safely access response properties to prevent native crashes
      try {
        int statusCode = response.statusCode;
        int contentLength = response.contentLength;
        HttpHeaders headers = response.headers;

        _business.endWebResponse(_requesetId, statusCode, contentLength, headers);
        _business.finishWebRequset(_requesetId, null);
      } catch (e) {
        // Handle potential native crashes when accessing response properties
        // This can happen if the native response object was released or is invalid
        _business.finishWebRequset(_requesetId, 'Error accessing response properties: $e');
      }

      return response;
    } catch (error) {
      _business.finishWebRequset(_requesetId, error.toString());
      throw error;
    }
  }

  @override
  HttpConnectionInfo? get connectionInfo => _httpClientRequest.connectionInfo;

  @override
  List<Cookie> get cookies => _httpClientRequest.cookies;

  @override
  Future<HttpClientResponse> get done => _httpClientRequest.done;

  @override
  Future flush() => _httpClientRequest.flush();

  @override
  HttpHeaders get headers => _httpClientRequest.headers;

  @override
  String get method => _httpClientRequest.method;

  @override
  Uri get uri => _httpClientRequest.uri;

  @override
  void write(Object? obj) => _httpClientRequest.write(obj);

  @override
  void writeAll(Iterable objects, [String separator = ""]) => _httpClientRequest.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _httpClientRequest.writeCharCode(charCode);

  @override
  void writeln([Object? obj = ""]) => _httpClientRequest.writeln(obj);
}
