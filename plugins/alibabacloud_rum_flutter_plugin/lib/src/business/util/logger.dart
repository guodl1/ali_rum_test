enum LogLevel { Info, Error, Debug }

class Logger {
  static Logger? _instance;
  LogLevel? _definedLogLevel;

  factory Logger() {
    if (_instance == null) {
      _instance = Logger.private();
    }
    return _instance!;
  }

  Logger.private() {
    this._definedLogLevel = LogLevel.Info;
  }

  set logLevel(LogLevel logLevel) => _definedLogLevel = logLevel;

  /// Is logging a debug log. This will only be logged if
  /// the customer activated the debug logs
  void d(String message, {LogLevel level = LogLevel.Debug}) {
    if (_definedLogLevel == LogLevel.Debug) {
      _logMessage(level, message);
    }
  }

  /// Is logging a info log. This log will always be displayed.
  /// So be careful when using it
  void i(String message, {LogLevel logType = LogLevel.Info}) {
    _logMessage(logType, message);
  }

  void e(String message, {LogLevel logType = LogLevel.Error}) {
    _logMessage(logType, message);
  }

  void _logMessage(LogLevel logType, String message) {
    if (!isStringNullOrEmpty(message)) {
      print(
          "[${_currentDate()}][${_getLogTypeString(logType)}][AlibabaCloudRUM]: $message");
    }
  }

  String _getLogTypeString(LogLevel logType) {
    if (logType == LogLevel.Error) {
      return "ERROR";
    } else if (logType == LogLevel.Debug) {
      return "DEBUG";
    } else {
      return "INFO";
    }
  }

  String _currentDate() {
    String date = DateTime.now().toIso8601String().replaceFirst("T", " ");
    return date.substring(0, date.indexOf("."));
  }

  static bool isStringNullOrEmpty(String? s) {
    return s == null || s.isEmpty || s.trim().isEmpty;
  }
}
