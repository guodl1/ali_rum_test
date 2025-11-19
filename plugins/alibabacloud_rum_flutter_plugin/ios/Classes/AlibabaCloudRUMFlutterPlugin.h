#import <Flutter/Flutter.h>

@interface AlibabaCloudRUMFlutterPlugin : NSObject<FlutterPlugin>

@property (nonatomic, strong) FlutterMethodChannel *channel;

+ (void)setNetworkTraceConfig:(NSDictionary *)config;

@end
@interface AlibabaCloudRUMFlutterNetworkModel : NSObject

@property (nonatomic, copy) NSString *requestUrl;
@property (nonatomic, strong) NSNumber *startTimeMs;
@property (nonatomic, strong) NSNumber *responseDataSize;
@property (nonatomic, strong) NSNumber *connectTimeMs;
@property (nonatomic, strong) NSNumber *responseTimeMs;
@property (nonatomic, strong) NSNumber *errorCode;
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSString *resourceType;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic, strong) NSDictionary *httpRequestHeader;
@property (nonatomic, strong) NSDictionary *httpResponseHeader;

@end

