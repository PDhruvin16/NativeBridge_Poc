#import "MyNativeBridge.h"
#import <React/RCTLog.h>

@implementation MyNativeBridge

RCT_EXPORT_MODULE(MyNativeModule)

RCT_EXPORT_METHOD(startObjectDetection:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  // Call Swift implementation
  [[MyNativeBridgeSwift shared] startObjectDetectionWithResolve:resolve reject:reject];
}

RCT_EXPORT_METHOD(stopObjectDetection)
{
  [[MyNativeBridgeSwift shared] stopObjectDetection];
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end