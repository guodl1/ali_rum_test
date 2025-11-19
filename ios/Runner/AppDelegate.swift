import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 初始化 Alibaba Cloud RUM SDK for iOS
    AlibabaCloudRUM.setConfigAddress("https://i920cij824-default-cn.rum.aliyuncs.com") // ConfigAddress 在创建 RUM 应用时获取
    AlibabaCloudRUM.start("i920cij824@7b474048378c8cd") // AppID 在创建 RUM 应用时获取
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
