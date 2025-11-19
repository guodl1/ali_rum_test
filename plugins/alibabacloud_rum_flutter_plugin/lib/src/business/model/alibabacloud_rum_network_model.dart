class AlibabaCloudRUMNetworkModel {
  String _requestUrl = "";
  int _startTimeMs = -1;
  int _responseDataSize = -1;
  String _method = "";
  String _resourceType = "";
  int _connectTimeMs = -1;
  int _errorCode = -1;
  int _responseStartTimeMs = -1;
  int _responseTimeMs = -1;
  String _errorMessage = "";
  Map _httpRequestHeader = {};
  Map _httpResponseHeader = {};

  String get requestUrl => this._requestUrl;
  int get startTimeMs => this._startTimeMs;
  int get responseDataSize => this._responseDataSize;
  String get method => this._method;
  String get resourceType => this._resourceType;
  int get connectTimeMs => this._connectTimeMs;
  int get responseStartTimeMs => this._responseStartTimeMs;
  int get responseTimeMs => this._responseTimeMs;
  String get errorMessage => this._errorMessage;
  Map get httpRequestHeader => this._httpRequestHeader;
  Map get httpResponseHeader => this._httpResponseHeader;
  int get errorCode => this._errorCode;

  AlibabaCloudRUMNetworkModel();

  set setRequestUrl(String url) {
    this._requestUrl = url;
  }

  set setStartTimeMs(int time) {
    this._startTimeMs = time;
  }

  set setConnectTimeMs(int time) {
    this._connectTimeMs = time;
  }

  set setMethod(String method) {
    this._method = method;
  }

  set setErrorMessage(String? errorMsg) {
    this._errorMessage = errorMsg ?? '';
  }

  set setResponseStartTimeMs(int responseStart) {
    this._responseStartTimeMs = responseStart;
  }

  set setResponseTimeMs(int responseTime) {
    this._responseTimeMs = responseTime;
  }

  set setHttpRequestHeader(Map requestMap) {
    this._httpRequestHeader = requestMap;
  }

  set setHttpResponseHeader(Map responseMap) {
    this._httpResponseHeader = responseMap;
  }

  set setErrorCode(int code) {
    this._errorCode = code;
  }

  set setResponseDataSize(int size) {
    this._responseDataSize = size;
  }

  set setResourceType(String type) {
    this._resourceType = type;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['requestUrl'] = this._requestUrl;
    data['startTimeMs'] = this._startTimeMs;
    data['responseDataSize'] = this._responseDataSize;
    data['method'] = this._method;
    data['resourceType'] = this._resourceType;
    data['connectTimeMs'] = this._connectTimeMs;
    data['errorCode'] = this._errorCode;
    data['responseTimeMs'] = this._responseTimeMs;
    data['errorMessage'] = this._errorMessage;
    data['httpRequestHeader'] = this._httpRequestHeader;
    data['httpResponseHeader'] = this._httpResponseHeader;
    return data;
  }
}
