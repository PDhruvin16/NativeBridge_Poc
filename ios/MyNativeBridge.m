#import "MyNativeBridge.h"
#import <React/RCTLog.h>
#import <UIKit/UIKit.h>

// Private interface BEFORE implementation
@interface MyNativeBridge ()
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, copy) RCTPromiseResolveBlock resolveBlock;
@property (nonatomic, copy) RCTPromiseRejectBlock rejectBlock;
@property (nonatomic, assign) BOOL hasResolved;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@end

@implementation MyNativeBridge

RCT_EXPORT_MODULE(MyNativeModule)

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

RCT_EXPORT_METHOD(startObjectDetection:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    self.resolveBlock = resolve;
    self.rejectBlock = reject;
    self.hasResolved = NO;
    self.frameCount = 0;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupCamera];
    });
}

RCT_EXPORT_METHOD(stopObjectDetection)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cleanup];
    });
}

- (void)setupCamera {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    
    if (status == AVAuthorizationStatusAuthorized) {
        [self startCamera];
    } else if (status == AVAuthorizationStatusNotDetermined) {
        __weak typeof(self) weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf startCamera];
                });
            } else {
                if (strongSelf.rejectBlock) {
                    strongSelf.rejectBlock(@"PERMISSION_DENIED", @"Camera permission denied", nil);
                }
            }
        }];
    } else {
        if (self.rejectBlock) {
            self.rejectBlock(@"PERMISSION_DENIED", @"Camera permission denied", nil);
        }
    }
}

- (void)startCamera {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                 mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionBack];
    
    if (!device) {
        if (self.rejectBlock) {
            self.rejectBlock(@"NO_CAMERA", @"Back camera not available", nil);
        }
        return;
    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if (error) {
        if (self.rejectBlock) {
            self.rejectBlock(@"CAMERA_ERROR", error.localizedDescription, error);
        }
        return;
    }
    
    if ([self.captureSession canAddInput:input]) {
        [self.captureSession addInput:input];
    }
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoQueue = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:self queue:self.videoQueue];
    
    if ([self.captureSession canAddOutput:videoOutput]) {
        [self.captureSession addOutput:videoOutput];
    }
    
    // Add preview layer
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    
    if (keyWindow) {
        self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        self.previewLayer.frame = keyWindow.bounds;
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [keyWindow.layer addSublayer:self.previewLayer];
    }
    
    [self.captureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)output 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection {
    
    if (self.hasResolved) {
        return;
    }
    
    self.frameCount++;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    VNDetectHumanRectanglesRequest *request = [[VNDetectHumanRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest *request, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error) {
            NSLog(@"Detection error: %@", error.localizedDescription);
            return;
        }
        
        NSArray<VNHumanObservation *> *observations = request.results;
        
        if (observations.count > 0 && !strongSelf.hasResolved) {
            NSMutableArray *results = [NSMutableArray array];
            
            for (VNHumanObservation *observation in observations) {
                NSDictionary *detection = @{
                    @"label": @"Person",
                    @"confidence": @(observation.confidence)
                };
                [results addObject:detection];
            }
            
            strongSelf.hasResolved = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (strongSelf.resolveBlock) {
                    strongSelf.resolveBlock(results);
                    [strongSelf cleanup];
                }
            });
        } else if (strongSelf.frameCount >= 60 && !strongSelf.hasResolved) {
            strongSelf.hasResolved = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (strongSelf.resolveBlock) {
                    strongSelf.resolveBlock(@[]);
                    [strongSelf cleanup];
                }
            });
        }
    }];
    
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:imageBuffer options:@{}];
    
    NSError *error = nil;
    [handler performRequests:@[request] error:&error];
    
    if (error) {
        NSLog(@"Failed to perform detection: %@", error.localizedDescription);
    }
}

- (void)cleanup {
    [self.captureSession stopRunning];
    [self.previewLayer removeFromSuperlayer];
    self.captureSession = nil;
    self.previewLayer = nil;
    self.hasResolved = NO;
    self.frameCount = 0;
    self.resolveBlock = nil;
    self.rejectBlock = nil;
}

@end