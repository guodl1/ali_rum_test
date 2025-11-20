import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { MethodChannel } from '@ohos/flutter_ohos'; // Add MethodChannel import

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    GeneratedPluginRegistrant.registerWith(flutterEngine);

    // Register method channel for quick login and account check
    const channel = new MethodChannel('com.example.tingyue/login');
    channel.setMethodCallHandler(async (call) => {
      if (call.method === 'quickLogin') {
        // 调用华为账号服务获取授权码
        try {
          const { authentication } = await import('@kit.AccountKit');
          const result = await authentication.quickLogin({
            scopes: [authentication.Scope.PHONE_NUMBER]
          });
          // 返回授权码给 Flutter
          return result; // result 为授权码字符串
        } catch (e) {
          console.error('HarmonyOS quickLogin error:', e);
          throw e;
        }
      } else if (call.method === 'isAccountAvailable') {
        // 简单返回 true，表示账号服务可用
        return true;
      }
      // 其他方法返回未实现
      throw new Error(`Method ${call.method} not implemented`);
    });
  }
}
