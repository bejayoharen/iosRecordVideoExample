//
//  ViewController.h
//  RecordVideo
//
//  Created by Bjorn Roche on 3/17/15.
//  Copyright (c) 2015 Bjorn Roche. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface RecordViewController : UIViewController<AVCaptureFileOutputRecordingDelegate>

@property (weak, nonatomic) IBOutlet UILabel *clipSavedLabel;
@property (weak, nonatomic) IBOutlet UIButton *recordStopButton;
- (IBAction)recordStopPressed:(id)sender;


@end

