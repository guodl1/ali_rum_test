import 'package:flutter/material.dart';

class AlibabaCloudRUMMaterialPageRoute<T> extends MaterialPageRoute<T> {
  String? routeName;

  AlibabaCloudRUMMaterialPageRoute(
      {@required builder, RouteSettings? settings, maintainState = true, bool fullscreenDialog = false, this.routeName})
      : assert(builder != null),
        assert(maintainState != null),
        super(builder: builder, settings: settings, maintainState: maintainState, fullscreenDialog: fullscreenDialog) {
    assert(opaque);
  }
}
