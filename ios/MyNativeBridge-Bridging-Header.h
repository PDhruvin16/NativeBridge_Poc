#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface MyNativeBridgeSwift : NSObject

+ (instancetype)shared;

- (void)startObjectDetectionWithResolve:(RCTPromiseResolveBlock)resolve
                                 reject:(RCTPromiseRejectBlock)reject;

- (void)stopObjectDetection;

@end