#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint alibabacloud_rum_flutter_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'alibabacloud_rum_flutter_plugin'
  s.version          = '1.0.9'
  s.summary          = 'AlibabaCloud Flutter Plugin'
  s.description      = 'AlibabaCloud Flutter Plugin'
  s.homepage         = 'https://help.aliyun.com/zh/arms/user-experience-monitoring'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AlibabaCloud RUM' => 'aliyunsdk@aliyun.com' }
  s.source           = { :path => '.' }
  s.source_files =  'Classes/AlibabaCloudRUMFlutterPlugin.h','Classes/AlibabaCloudRUMFlutterPlugin.m','Classes/OpenRUMFlutterPlugin.h','Classes/OpenRUMFlutterPlugin.m'#, 'Classes/*.swift'
  # s.vendored_frameworks = 'Classes/*.xcframework'
  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-lObjC' }
  s.dependency 'Flutter'
  s.dependency 'AlibabaCloudRUM', '1.0.9'
  s.platform = :ios, '8.0'
  s.library   = "c++","resolv"
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386','OTHER_LDFLAGS' => '-ObjC'}
  s.swift_version = '5.0'
end
