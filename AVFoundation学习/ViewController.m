//
//  ViewController.m
//  AVFoundation学习
//
//  Created by RenXiangDong on 17/1/9.
//  Copyright © 2017年 RenXiangDong. All rights reserved.
//
#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "XMFaceView.h"

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate,AVCaptureMetadataOutputObjectsDelegate>
@property (weak, nonatomic) IBOutlet UIButton *lightButton;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *switchButton;
@property (weak, nonatomic) IBOutlet UIButton *videoButton;
@property (weak, nonatomic) IBOutlet UIButton *phtotoButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageIcon;
@property (weak, nonatomic) IBOutlet UIButton *tackButton;


@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureDeviceInput *activeVideoInput;
@property (nonatomic, retain) AVCaptureStillImageOutput *imageOutput;
@property (nonatomic, retain) AVCaptureMovieFileOutput *movieOutput;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer* previewLayer;
@property (nonatomic, strong) AVCaptureMetadataOutput *metaOutput;
@property (nonatomic, strong) UIView *faceOverLayer;
@property (nonatomic, strong) NSMutableDictionary *faceDict;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, assign) int recodeTime;

@property (nonatomic, assign) BOOL isVideo;//是录像还是拍照

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.faceDict = [[NSMutableDictionary alloc] init];
    [self setUpCaptureSession];
    [self prepareUI];
}
#pragma mark - Private
#pragma mark - UI相关
- (void)prepareUI {
    self.tackButton.layer.cornerRadius = 30;
    self.tackButton.layer.masksToBounds = YES;
    self.phtotoButton.selected = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToFocus:)];
    [self.view addGestureRecognizer:tap];
    /* 人脸识别的层 */
    self.faceOverLayer = [[UIView alloc] init];
    self.faceOverLayer.userInteractionEnabled = NO;
    self.faceOverLayer.frame = [UIScreen mainScreen].bounds;
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0/1000;
    self.faceOverLayer.layer.sublayerTransform = transform;
    [self.view addSubview:self.faceOverLayer];
}
- (void)tapToFocus:(UITapGestureRecognizer*)tap {
    CGPoint point = [tap locationInView:self.view];
    CGPoint cameraPoint = CGPointMake(point.x/[UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    [self focusAtPoint:cameraPoint];
}
/* 初始化 */
- (void)setUpCaptureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    /* videoInput */
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    if ([self.captureSession canAddInput:videoInput]) {
        [self.captureSession addInput:videoInput];
        self.activeVideoInput = videoInput;
    }
    /* audioInput */
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    if ([self.captureSession canAddInput:audioInput]) {
        [self.captureSession addInput:audioInput];
    }
    /* imageOutput */
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.imageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
    if ([self.captureSession canAddOutput:self.imageOutput]) {
        [self.captureSession addOutput:self.imageOutput];
    }
    /* videoOutput */
    self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.captureSession canAddOutput:self.movieOutput]) {
        [self.captureSession addOutput:self.movieOutput];
    }
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.previewLayer.frame = [UIScreen mainScreen].bounds;
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    self.videoQueue = dispatch_queue_create("rxdVideoQueue", NULL);
    /* 人脸识别 */
    self.metaOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([self.captureSession canAddOutput:self.metaOutput]) {
        [self.captureSession addOutput:self.metaOutput];
        self.metaOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
       [self.metaOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    }
    [self startSession];
}
/* 开始跑session */
- (void)startSession {
    if (![self.captureSession isRunning]) {
        dispatch_async(self.videoQueue, ^{
            [self.captureSession startRunning];
        });
    }
}
/* 停止跑session */
- (void)stopSession {
    if ([self.captureSession isRunning]) {
        dispatch_async(self.videoQueue, ^{
            [self.captureSession stopRunning];
        });
    }
}
/* 切换摄像头，返回切换后的摄像头的position */
- (AVCaptureDevicePosition)switchCamera {
    if ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count < 2) {
        return -1;
    }
    AVCaptureDevice *device = [self inactiveDevice];
    AVCaptureDevicePosition position = device.position;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if (videoInput) {
        [self.captureSession beginConfiguration];
        [self.captureSession removeInput:self.activeVideoInput];
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeVideoInput = videoInput;
        } else {
            [self.captureSession addInput:self.activeVideoInput];
            position = self.activeVideoInput.device.position;
        }
        [self.captureSession commitConfiguration];
    }
    return position;
}
#pragma mark  - 摄像头相关
/* 通过position来获得对应device */
- (AVCaptureDevice*)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}
- (AVCaptureDevice*)activeDevice {
    return self.activeVideoInput.device;
}
/* 未使用的device */
- (AVCaptureDevice*)inactiveDevice {
    if ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1  ) {
        if ([self activeDevice].position == AVCaptureDevicePositionBack) {
            return [self cameraWithPosition:AVCaptureDevicePositionFront];
        } else {
            return [self cameraWithPosition:(AVCaptureDevicePositionBack)];
        }
    }
    return nil;
}
#pragma mark - 焦距相关
- (BOOL)cameraSupportTapToFocus {
    return [self.activeVideoInput.device isFocusPointOfInterestSupported];
}
/* 聚焦在某一点 */
- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = self.activeVideoInput.device;
    if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:(AVCaptureFocusModeAutoFocus)]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        }
    }
}
#pragma mark - 拍照相关
/* 拍照 */
- (void)captureStillImage {
    AVCaptureConnection *connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = [self currentVideoOrientation];
    }
    __weak typeof(self) weakSelf = self;
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer != nil) {
            NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image = [UIImage imageWithData:data];
            UIImage *newImage = [self renderFaceInPicture:image];
            
             UIImageWriteToSavedPhotosAlbum(newImage, weakSelf, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }
        
    }];
}
- (UIImage*)renderFaceInPicture:(UIImage*)image {
    if (_faceDict.count == 0) {
        return image;
    }
    CGFloat scale = image.size.width/kScreenWidth;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0);
    [image drawAtPoint:CGPointZero];
    for (XMFaceView *faceView in self.faceDict.allValues) {
        UIImage *faceImage = [self shootFromView:faceView];
        CGFloat X = faceView.frame.origin.x * scale;
        CGFloat Y = faceView.frame.origin.y * scale;
        CGFloat W = faceView.frame.size.width *scale;
        CGFloat H = faceView.frame.size.height * scale;
        [faceImage drawInRect:CGRectMake(X, Y, W, H)];
    }
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
- (UIImage*)shootFromView:(UIView*)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
/* 拍照保存完成后调用 */
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    
}
/* 获取当前手机重力方向 */
- (AVCaptureVideoOrientation)currentVideoOrientation {
    AVCaptureVideoOrientation orientation;
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            break;
    }
    return orientation;
}
#pragma mark - 录像相关
- (BOOL)isRecording {
    return self.movieOutput.isRecording;
}
/* 开始录像 */
- (void)startRecording {
    if (![self isRecording]) {
        AVCaptureConnection *connection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.isVideoOrientationSupported) {
            connection.videoOrientation = [self currentVideoOrientation];
        }
        AVCaptureDevice *device = [self activeDevice];
        if (device.isSmoothAutoFocusSupported) {
            if ([device lockForConfiguration:nil]) {
                device.smoothAutoFocusEnabled = YES;
                [device unlockForConfiguration];
            }
        }
        [self.movieOutput startRecordingToOutputFileURL:[self uniqueURL] recordingDelegate:self];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
}
- (void)stopRecording {
    if ([self isRecording]) {
        [self.movieOutput stopRecording];
        [self.timer invalidate];
        self.recodeTime = 0;
    }
}
- (NSURL*)uniqueURL {
    NSString *dirPath = NSTemporaryDirectory();
    NSString *path = [dirPath stringByAppendingPathComponent:@"rxd.mov"];
    NSLog(@"\n\n\n\n\n\n\n\n%@\n\n\n\n\\n\n\n",dirPath);
    return [NSURL fileURLWithPath:path];
}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    if (error == nil) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
            
        }];
    }
}
- (void)timerAction {
    self.recodeTime ++;
}
#pragma mark - 人脸识别
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"\n\n%@\n\n",metadataObjects);
    NSArray *transformedFaces = [self transformedFaceFromFace:metadataObjects];
    NSMutableArray *lostFaces = [self.faceDict.allKeys mutableCopy];
    for (AVMetadataFaceObject *face in transformedFaces) {
        [lostFaces removeObject:@(face.faceID)];
        UIView *layer = self.faceDict[@(face.faceID)];
        if (!layer) {
            layer = [self makeFaceLayer];
            [self.faceOverLayer addSubview:layer];
            self.faceDict[@(face.faceID)] = layer;
        }
        layer.layer.transform = CATransform3DIdentity;
        ;
        layer.frame = CGRectMake(face.bounds.origin.x , face.bounds.origin.y - (face.bounds.size.height), face.bounds.size.width, face.bounds.size.height * 3);
        NSLog(@"%@",layer);
    }
    for (NSNumber *faceID in lostFaces) {
        UIView *layer = self.faceDict[faceID];
        [layer removeFromSuperview];
        [self.faceDict removeObjectForKey:faceID];
    }
}
- (UIView*)makeFaceLayer {
    UIView *layer = [XMFaceView viewWithFrame:CGRectZero];
    return layer;
}
/* 将坐标转换到previewLayer层 */
- (NSArray*)transformedFaceFromFace:(NSArray*)faces {
    NSMutableArray *newFaces = [[NSMutableArray alloc] init];
    for (AVMetadataObject *face in faces) {
        AVMetadataObject *newFace = [self.previewLayer transformedMetadataObjectForMetadataObject:face];
        [newFaces addObject:newFace];
    }
    return newFaces;
}

#pragma mark - 点击事件
/* 拍照、录像大按钮 */
- (IBAction)tackPhotoAction:(UIButton *)sender {
    if (self.isVideo) {
        self.tackButton.selected = !self.tackButton.selected;
        if (self.tackButton.selected == YES) {
            [self startRecording];
        } else {
            [self stopRecording];
        }
    } else {
        [self captureStillImage];
    }
}
/* 切换为录像状态 */
- (IBAction)switchToVideo:(UIButton *)sender {
    self.timeLabel.hidden = NO;
    [self.tackButton setImage:[UIImage imageNamed:@"Start"] forState:(UIControlStateNormal)];
    [self.tackButton setImage:[UIImage imageNamed:@"Stop"] forState:(UIControlStateSelected)];
    self.isVideo = YES;
    self.videoButton.selected = YES;
    self.phtotoButton.selected = NO;
    self.tackButton.selected = NO;
}
/* 切换为拍照状态 */
- (IBAction)switchToPhoto:(id)sender {
    self.timeLabel.hidden = YES;
    [self.tackButton setImage:[UIImage imageNamed:@"rxphto"] forState:(UIControlStateNormal)];
    [self.tackButton setImage:[UIImage imageNamed:@"rxphto"] forState:(UIControlStateSelected)];
    self.isVideo = NO;
    self.videoButton.selected = NO;
    self.phtotoButton.selected = YES;
    self.tackButton.selected = NO;
}
/* 切换闪光灯状态 */
- (IBAction)lightSwitch:(UIButton *)sender {
}
/* 切换前后摄像头 */
- (IBAction)switchFrontOrBack:(UIButton *)sender {
    AVCaptureDevicePosition position = [self switchCamera];
    if (position == AVCaptureDevicePositionFront) {
        [self.switchButton setTitle:@"切为后置" forState:(UIControlStateNormal)];
    } else if (position == AVCaptureDevicePositionBack) {
        [self.switchButton setTitle:@"切为前置" forState:(UIControlStateNormal)];
    } else {
        [self.switchButton setTitle:@"不可切换" forState:(UIControlStateNormal)];
    }
}

#pragma mark - getter & setter
- (void)setRecodeTime:(int)recodeTime {
    _recodeTime = recodeTime;
    int intTime = (int)recodeTime;
    int seconde = intTime % 60;
    int min = (intTime / 60)% 60;
    int hour = (intTime / 360)% 60;
    self.timeLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d",hour,min,seconde];
}

@end
