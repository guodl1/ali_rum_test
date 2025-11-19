import 'dart:io';

import '../../business/alibabacloud_rum_business_interface.dart';
import 'alibabacloud_rum_http_client.dart';

class AlibabaCloudRUMHttpOverrides extends HttpOverrides {
  AlibabaCloudRUMBusinessInterface _business;
  var _originOverride;
  AlibabaCloudRUMHttpOverrides(this._business, this._originOverride);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    //兼容逻辑
    if (_originOverride is HttpOverrides) {
      return AlibabaCloudRUMHttpClient(_originOverride.createHttpClient(context), _business);
    }
    return AlibabaCloudRUMHttpClient(super.createHttpClient(context), _business);
  }
}
