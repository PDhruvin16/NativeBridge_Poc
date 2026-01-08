#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>

@interface MyNativeBridge : NSObject <RCTBridgeModule, AVCaptureVideoDataOutputSampleBufferDelegate>

@end