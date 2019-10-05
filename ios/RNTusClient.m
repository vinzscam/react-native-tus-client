#import "RNTusClient.h"
#import "TUSKit.h"

#define ON_SUCCESS @"onSuccess"
#define ON_ERROR @"onError"
#define ON_PROGRESS @"onProgress"

@interface RNTusClient ()

@property(nonatomic, strong, readonly) NSMutableDictionary<NSString*, TUSSession*> *sessions;
@property(nonatomic, strong, readonly) TUSUploadStore *uploadStore;
@property(nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *endpoints;

@end

@implementation RNTusClient

@synthesize uploadStore = _uploadStore;

- (id)init {
    if(self = [super init]) {
        _sessions = [NSMutableDictionary new];
        _endpoints = [NSMutableDictionary new];
    }
    return self;
}

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

- (TUSUploadStore *)uploadStore {
    if(_uploadStore == nil) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *applicationSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
        _uploadStore = [[TUSFileUploadStore alloc] initWithURL:[applicationSupportURL URLByAppendingPathComponent:@"__uploadStore.tmp"]];
    }
    return _uploadStore;
}

- (TUSSession *)sessionFor:(NSString *)endpoint {
    TUSSession *session = [_sessions objectForKey:endpoint];
    if(session == nil) {
        session = [[TUSSession alloc] initWithEndpoint:[[NSURL alloc] initWithString:endpoint] dataStore:self.uploadStore allowsCellularAccess:YES];
        [self.sessions setObject:session forKey:endpoint];
    }
    return session;
}

- (TUSResumableUpload *)restoreUpload:(NSString *)uploadId {
    NSString *endpoint = self.endpoints[uploadId];
    TUSSession *session = [self sessionFor:endpoint];
    return [session restoreUpload:uploadId];
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()


- (NSArray<NSString *> *)supportedEvents
{
    return @[ON_SUCCESS, ON_ERROR, ON_PROGRESS];
}

RCT_EXPORT_METHOD(createUpload:(NSString *)fileUrl
                  options:(NSDictionary *)options
                  onCreated:(RCTResponseSenderBlock)onCreatedCallback
                  )
{
    NSString *endpoint = [NSString stringWithString: options[@"endpoint"]];
    NSDictionary *headers = options[@"headers"];
    NSDictionary *metadata = options[@"metadata"];

    TUSSession *session = [self sessionFor:endpoint];

    NSURL *url = [NSURL fileURLWithPath:[fileUrl hasPrefix:@"file://"]
      ? [fileUrl substringFromIndex:7]
      : fileUrl
    ];
    TUSResumableUpload *upload = [session createUploadFromFile:url retry:3 headers:headers metadata:metadata];

    [self.endpoints setObject:endpoint forKey: upload.uploadId];

    __weak TUSResumableUpload *_upload = upload;
    __weak RNTusClient *weakSelf = self;
    
    
    upload.resultBlock = ^(NSURL * _Nonnull fileURL) {
        [weakSelf sendEventWithName:ON_SUCCESS body:@{
            @"uploadId": _upload.uploadId,
            @"uploadUrl": fileURL.absoluteString
            }];
    };

    upload.failureBlock = ^(NSError * _Nonnull error) {
        [weakSelf sendEventWithName:ON_ERROR body:@{ @"uploadId": _upload.uploadId, @"error": error }];
    };

    upload.progressBlock = ^(int64_t bytesWritten, int64_t bytesTotal) {
        [weakSelf sendEventWithName:ON_PROGRESS body:@{
            @"uploadId": _upload.uploadId,
            @"bytesWritten": [NSNumber numberWithLongLong: bytesWritten],
            @"bytesTotal": [NSNumber numberWithLongLong:bytesTotal]
        }];
    };

    onCreatedCallback(@[upload.uploadId]);
}

RCT_EXPORT_METHOD(resume:(NSString *)uploadId withCallback:(RCTResponseSenderBlock)callback)
{
    TUSResumableUpload *upload = [self restoreUpload:uploadId];
    if(upload == nil) {
      callback(@[@NO]);
      return;
    }
    [upload resume];
    callback(@[@YES]);
}

RCT_EXPORT_METHOD(abort:(NSString *)uploadId withCallback:(RCTResponseSenderBlock)callback)
{
    TUSResumableUpload *upload = [self restoreUpload:uploadId];
    if(upload != nil) {
      [upload stop];
    }
    callback(@[]);
}

@end
