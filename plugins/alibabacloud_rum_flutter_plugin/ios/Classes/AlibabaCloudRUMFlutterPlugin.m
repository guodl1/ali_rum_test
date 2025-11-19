#import "AlibabaCloudRUMFlutterPlugin.h"
#import "AlibabaCloudRUMSDK/AlibabaCloudRUMSDK.h"
@import AlibabaCloudRUM;

@implementation AlibabaCloudRUMFlutterPlugin
+ (instancetype)sharedObj {
    static AlibabaCloudRUMFlutterPlugin *sharedObj;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedObj = [[AlibabaCloudRUMFlutterPlugin alloc] init];
    });
    return sharedObj;
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"alibabacloud_rum_flutter_plugin"
                                                                binaryMessenger:[registrar messenger]
    ];
    AlibabaCloudRUMFlutterPlugin *instatance = [AlibabaCloudRUMFlutterPlugin sharedObj];
    instatance.channel = channel;
    [registrar addMethodCallDelegate:instatance channel:channel];
}
+ (void)setNetworkTraceConfig:(NSDictionary *)config {
    //When invoking channels on the platform side destined for Flutter, they need to be invoked on the platform’s main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[AlibabaCloudRUMFlutterPlugin sharedObj].channel invokeMethod:@"setNetworkTraceConfig" arguments:config];
    });
}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    // 网络
    if ([@"reportNetwork" isEqualToString:call.method]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            AlibabaCloudRUMFlutterNetworkModel *netModel = [[AlibabaCloudRUMFlutterNetworkModel alloc] init];
            [netModel setValuesForKeysWithDictionary:call.arguments];
            
            NSURL *url = [NSURL URLWithString:netModel.requestUrl];
            
            [AlibabaCloudRUMSDK flutterReportResource:url
                                               method:netModel.method
                                          connectTime:[netModel.connectTimeMs ?: @0 integerValue]
                                         responseTime:[netModel.responseTimeMs ?: @0 integerValue]
                                                 type:@"api"
                                     responseDataSize:[netModel.responseDataSize ?: @0 integerValue]
                                            errorCode:[netModel.errorCode ?: @-1 integerValue]
                                         errorMessage:netModel.errorMessage ?: @""
                                       requestHeaders:[netModel.httpRequestHeader ?: @{} mutableCopy]
                                      responseHeaders:[netModel.httpResponseHeader ?: @{} mutableCopy]
            ];
        }
    // 崩溃
    } else if ([call.method isEqualToString:@"reportCrash"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUMSDK flutterReportException:call.arguments[@"errorValue"]
                                               causeBy:call.arguments[@"reason"]
                                             errorDump:call.arguments[@"stacktrace"]
            ];
        } 
    // 视图
    } else if ([call.method isEqualToString:@"reportView"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUMSDK flutterReportView:call.arguments[@"viewId"]
                                         loadTime:[call.arguments[@"loadTime"] integerValue]
                                            enter:[call.arguments[@"model"] intValue] == 1
                                             name:call.arguments[@"name"]
                                           method:call.arguments[@"method"]
            ];
        }
    // 自定义异常
    } else if ([call.method isEqualToString:@"setCustomException"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM setCustomException:call.arguments[@"exceptionType"]
                                        causeBy:call.arguments[@"causedBy"]
                                      errorDump:call.arguments[@"errorDump"]
            ];
        }
    // 自定义事件
    } else if ([call.method isEqualToString:@"setCustomEvent"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            NSString *name = call.arguments[@"name"];
            NSString *group = call.arguments[@"group"];
            NSString *snapshots = call.arguments[@"snapshots"];
            NSString *value = call.arguments[@"value"];
            NSDictionary *attributes = call.arguments[@"attributes"];
            [AlibabaCloudRUM setCustomEvent:name
                                      group:[group isKindOfClass:[NSNull class]] ? nil : group
                                  snapshots:[snapshots isKindOfClass:[NSNull class]] ? nil : snapshots
                                      value:[value isKindOfClass:[NSNull class]] ? 0 : [value doubleValue]
                                       info:[attributes isKindOfClass:[NSNull class]] ? nil : attributes
            ];
        }
    // 自定义日志
    } else if ([call.method isEqualToString:@"setCustomLog"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            NSString *logInfo = call.arguments[@"logInfo"];
            NSString *name = call.arguments[@"name"];
            NSString *snapshots = call.arguments[@"snapshots"];
            NSString *level = call.arguments[@"level"];
            NSDictionary *attributes = call.arguments[@"attributes"];
            [AlibabaCloudRUM setCustomLog:logInfo
                                     name:[name isKindOfClass:[NSNull class]] ? nil : name
                                snapshots:[snapshots isKindOfClass:[NSNull class]] ? nil : snapshots
                                    level:[level isKindOfClass:[NSNull class]] ? nil : level
                                     info:[attributes isKindOfClass:[NSNull class]] ? nil : attributes
            ];
        }
    // 自定义指标
    } else if ([call.method isEqualToString:@"setCustomMetric"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM setCustomMetric:call.arguments[@"metricName"]
                                       value:[call.arguments[@"metricValue"] integerValue]
                                       param:call.arguments[@"param"]
            ];
        }
    // 自定义用户名称（userId不允许设置）
    } else if ([call.method isEqualToString:@"setUserID"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM setUserName:call.arguments[@"userID"]];
        }
    // 自定义用户扩展信息
    } else if ([call.method isEqualToString:@"setUserExtraInfo"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM setUserExtraInfo:call.arguments];
        }
    // 增加用户扩展信息
    } else if ([call.method isEqualToString:@"addUserExtraInfo"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM addUserExtraInfo:call.arguments];
        }
    // 自定义全局属性
    } else if ([call.method isEqualToString:@"setExtraInfo"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM setExtraInfo:call.arguments];
        }
    // 增加全局属性
    } else if ([call.method isEqualToString:@"addExtraInfo"]) {
        if ([call.arguments isKindOfClass:[NSDictionary class]]) {
            [AlibabaCloudRUM addExtraInfo:call.arguments];
        }
    // 读取端到端打通配置
    } else if ([call.method isEqualToString:@"getNetworkTraceConfig"]) {
        NSDictionary *dic = [AlibabaCloudRUMSDK getNetworkTraceConfig];;
        if (dic.allKeys != 0) {
            result(dic);
            return;
        } else {
            result(nil);
            return;
        }
    // 读取设备id
    }  else if ([call.method isEqualToString:@"getDeviceId"]) {
        NSString *deviceId = [AlibabaCloudRUM getDeviceId];
        result(deviceId);
        return;
    }
    result(@"success");
}
+ (BOOL)isNoNullAndBlankStr:(NSString *)str{
    return str.length > 0 && ![str isEqualToString:@"null"];
}
@end

@implementation AlibabaCloudRUMFlutterNetworkModel
-(void)setValue:(id)value forUndefinedKey:(NSString *)key{
    
}
@end
