#import "OpenRUMFlutterPlugin.h"
#import "AlibabaCloudRUMFlutterPlugin.h"

@implementation OpenRUMFlutterPlugin
/**
 单例模型

 @return 单例
 */
+ (instancetype)sharedObj {
    
    static OpenRUMFlutterPlugin *sharedObj;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedObj = [[OpenRUMFlutterPlugin alloc] init];
    });
    return sharedObj;
}

+ (void)setNetworkTraceConfig:(NSDictionary *)config {
    [AlibabaCloudRUMFlutterPlugin setNetworkTraceConfig: config];
}

@end
