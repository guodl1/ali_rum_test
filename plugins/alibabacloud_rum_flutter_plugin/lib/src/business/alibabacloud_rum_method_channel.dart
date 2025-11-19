import 'package:alibabacloud_rum_flutter_plugin/src/business/util/logger.dart';
import 'package:flutter/services.dart';

abstract class MethodChannelContainer {
  factory MethodChannelContainer() => MethodChannelContainerImpl();

  MethodChannel get methodChannel;

  Future<void> onMethodChannelInvoke(String methodName, [Map? params]);
}

class MethodChannelContainerImpl implements MethodChannelContainer {
  static MethodChannelContainer? _instance;
  final MethodChannel _methodChannel;

  factory MethodChannelContainerImpl() {
    if (_instance == null) {
      const MethodChannel _methodChannel = MethodChannel("alibabacloud_rum_flutter_plugin");
      MethodChannelContainerImpl.private(_methodChannel);
    }
    return _instance as MethodChannelContainerImpl;
  }

  MethodChannelContainerImpl.private(this._methodChannel) {
    _instance = this;
  }

  @override
  MethodChannel get methodChannel {
    return _methodChannel;
  }

  Future<void> onMethodChannelInvoke(String methodName, [Map? params]) async {
    try {
      await _methodChannel.invokeMethod(methodName, params);
    } catch (e) {
      Logger().e(e.toString());
    }
  }
}
