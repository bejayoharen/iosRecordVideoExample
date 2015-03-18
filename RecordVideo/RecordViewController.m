//
//  ViewController.m
//  RecordVideo
//
//  Created by Bjorn Roche on 3/17/15.
//  Copyright (c) 2015 Bjorn Roche. All rights reserved.
//

#import "RecordViewController.h"

#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVCaptureSession.h>

#define FILENAME (@"Recording.mov")

typedef enum {
    kPlayModeUnset,
    kPlayModeStopped,
    kPlayModeRecording,
} PlayMode;


@interface RecordViewController () {
}

@property (nonatomic) PlayMode playMode;
@property (strong,nonatomic) AVCaptureSession *session;
@property (strong,nonatomic) NSArray *videoDevices;
@property (strong,nonatomic) AVCaptureDeviceInput *input;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (strong,nonatomic) AVCaptureMovieFileOutput *output;
@property (nonatomic) bool success;
@property (readonly) int currentCameraIndex;

@end

@implementation RecordViewController

+ (NSURL *) outputUrl {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:FILENAME];
    return [NSURL fileURLWithPath:path];
}

+ (void)clean
{
    NSString *path = [[RecordViewController outputUrl] path];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark basic view conroller management

- (void)viewDidLoad
{
    [super viewDidLoad];
    [RecordViewController clean];
    
    self.playMode = kPlayModeUnset;
    self.playMode = kPlayModeStopped;
    self.session = [[AVCaptureSession alloc] init];
    
    // setup preview:
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.captureVideoPreviewLayer setFrame:self.view.bounds];
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.captureVideoPreviewLayer.connection.automaticallyAdjustsVideoMirroring = YES;
    
    self.view.backgroundColor = [UIColor blackColor];
    [self.view.layer addSublayer:self.captureVideoPreviewLayer];
    
    AVCaptureDevice *defaultDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //FIXME: what if the device doesn't have a camera?
    _currentCameraIndex = -1;
    self.videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    if( [self.videoDevices count] > 1 )
        _currentCameraIndex = 0;
    for( int i=0; i<[self.videoDevices count]; ++i ) {
        AVCaptureDevice *d = self.videoDevices[i];
        if( [[d uniqueID] isEqualToString:[defaultDevice uniqueID]] )
            _currentCameraIndex = i;
    }
    [self setupCamera];
    
    //setup output
    self.output = [[AVCaptureMovieFileOutput alloc] init];
    [self.session addOutput:self.output];
    
    [self.session startRunning];
    [self.view addSubview:self.recordStopButton];
}

-(void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.captureVideoPreviewLayer setFrame:self.view.bounds];
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    //self.captureVideoPreviewLayer.connection.videoOrientation = [UIDevice currentDevice].orientation;
    self.captureVideoPreviewLayer.connection.automaticallyAdjustsVideoMirroring = YES;
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.success = false;
    [self.session stopRunning];
}

-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.session stopRunning];
    self.output = nil;
    self.session = nil;
    self.captureVideoPreviewLayer = nil;

    self.videoDevices = nil;
    self.input = nil;
    self.captureVideoPreviewLayer = nil;
}

#pragma mark playback/record

-(void) setPlayMode:(PlayMode)playMode
{
    _playMode = playMode;
}

- (void)setupCamera:(BOOL) on {
    AVCaptureDevice *device = [[self input] device];
    NSError *error;
    CGPoint center = CGPointMake(0.5f, 0.5f);
    if ([device lockForConfiguration:&error]) {
        if( on ) {
            // we are pre-rolling:
            if( [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance] ) {
                [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
            }
            if( [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] ) {
                [device setFocusPointOfInterest:center];
                [device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            }
            if( [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] ) {
                [device setExposurePointOfInterest:center];
                [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [device unlockForConfiguration];
        } else {
            if( [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked] ) {
                [device setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
            }
            if( [device isFocusModeSupported:AVCaptureFocusModeLocked] ) {
                [device setFocusPointOfInterest:center];
                [device setFocusMode:AVCaptureFocusModeLocked];
            }
            if( [device isExposureModeSupported:AVCaptureExposureModeLocked] ) {
                [device setExposurePointOfInterest:center];
                [device setExposureMode:AVCaptureExposureModeLocked];
            }
            [device unlockForConfiguration];
        }
    } else {
        NSLog( @"Could not lock device to change torch mode: %@", error );
    }
}

- (void) startRecording
{
    //[self.session stopRunning]; <-- calling this here actually messes things up!
    [RecordViewController clean];
    [self setupCamera:YES];
    [self.output startRecordingToOutputFileURL:[RecordViewController outputUrl] recordingDelegate:self];
    [self.session startRunning];
    self.playMode = kPlayModeRecording;
}

- (void) stopRecording:(BOOL) success
{
    self.playMode = kPlayModeStopped;
    [self setupCamera:NO];
    self.success = success;
    [self.session stopRunning];
    [self.session startRunning];
}

- (IBAction)recordStopPressed:(id)sender
{
    switch( self.playMode ) {
        case kPlayModeUnset:
            //fall through
        case kPlayModeStopped: {
            // get desired video orientation from device orientation when the recording started.
            //http://stackoverflow.com/questions/7845520/why-does-avcapturevideoorientation-landscape-modes-result-in-upside-down-still-i
            AVCaptureVideoOrientation videoOrientation;
            switch ([UIDevice currentDevice].orientation) {
                case UIDeviceOrientationLandscapeLeft:
                    videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                    break;
                case UIDeviceOrientationLandscapeRight:
                    videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                    break;
                case UIDeviceOrientationPortraitUpsideDown:
                    videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
                    break;
                default:
                    videoOrientation = AVCaptureVideoOrientationPortrait;
                    break;
            }
            [self.output.connections[0] setVideoOrientation:videoOrientation];
            
            [self startRecording];

            break;
        }
        case kPlayModeRecording:
            [self stopRecording:true];
            break;
    }
}

- (void) completeRecording:(NSURL *)outputFileURL
{
    if( self.success && self.session ) {
        NSLog( @"Capture success. Storing." );
    } else {
        NSLog( @"Capture canceled. Deleting." );
        if( self.output.isRecording ) {
            NSLog( @"IsRecording" );
            [self.output stopRecording];
        }
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error;
        if( [fm fileExistsAtPath:outputFileURL.path] )
            if( ![fm removeItemAtURL:outputFileURL error:&error] )
                NSLog( @"File deletion failed due to: %@", error );
    }
}

- (void) setupCamera
{
    if( self.input )
        [self.session removeInput:self.input];
    NSError *error = nil;
    if( self.currentCameraIndex == -1 )
        return;
    self.input = [AVCaptureDeviceInput
                  deviceInputWithDevice:self.videoDevices[self.currentCameraIndex]
                  error:&error];
    
    // this session preset is supported by all inputs:
    self.session.sessionPreset = AVCaptureSessionPresetMedium;
    // change input
    if (!self.input) {
        NSLog( @"Error setting up video input: %@", error );
        // FIXME: Handle the error appropriately: we should display an error
        // and set the comera selector back to the original value
        return;
    }
    [self.session addInput:self.input];
}

#pragma mark AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog( @"Starting capture" );
}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    if( error ) {
        NSLog( @"Error capturing: %@", error );
    }
    NSLog( @"Completing capture to: %@", outputFileURL );
    if( outputFileURL ) {
        [self performSelectorOnMainThread:@selector(completeRecording:) withObject:outputFileURL waitUntilDone:NO];
    }
}

@end
