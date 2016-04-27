//
//  ViewController.h
//  Simple MetaWear Test
//
//  Created by Eddie on 2/25/16.
//  Copyright © 2016 Eddie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MetaWear/MetaWear.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController : UIViewController
@property (strong, atomic) NSMutableArray *accelerometerDataArrays;
@property (strong, atomic) NSMutableArray *gyroDataArrays;
@property (strong, atomic) NSMutableArray *deviceIdentifiers;
@property (strong, atomic) NSMutableArray *deviceInformation;
@property (strong, atomic) CBCentralManager *bluetoothManager;
@property (weak, nonatomic) IBOutlet UILabel *connectedDevicesLabel;

@property (weak, nonatomic) IBOutlet UITableView *selectDevicesTable;
@property (weak, nonatomic) IBOutlet UIPickerView *devicePicker;
@property (weak, nonatomic) IBOutlet UIScrollView *scroller;
@property (weak, nonatomic) IBOutlet UILabel *sampleFrequencyLabel;
@property (weak, nonatomic) IBOutlet UISlider *sampleFrequencySlider;
@property (weak, nonatomic) IBOutlet UILabel *downloadProgressAccel;
@property (weak, nonatomic) IBOutlet UILabel *downloadProgressGyro;

@property (weak, nonatomic) IBOutlet UIButton *connectDevicesButton;
@property (weak, nonatomic) IBOutlet UIButton *refreshListButton;
@property (weak, nonatomic) IBOutlet UIButton *flashRed;

@property (weak, nonatomic) IBOutlet UIButton *stopRecordingButton;
@property (weak, nonatomic) IBOutlet UIButton *startRecordingButton;
@property (weak, nonatomic) IBOutlet UIButton *startLoggingButton;
@property (weak, nonatomic) IBOutlet UIButton *stopLoggingButton;
@property (weak, nonatomic) IBOutlet UIButton *resetLoggingButton;

@property MBLMetaWearManager *manager;

- (IBAction)startSearch:(id)sender; 
- (IBAction)startRecording:(id)sender;

- (IBAction)refreshConnectedMetaWearsLabel:(id)sender;
- (IBAction)flashDevice:(id)sender;
- (void)centralManagerDidUpdateState:(CBCentralManager *)central;

- (IBAction)stopRecording:(id)sender;
- (IBAction)disconnectDevices:(id)sender;
- (IBAction)refresh_picker:(id)sender;
//- (IBAction)exitProgram:(id)sender;

- (void)updateLabel : (NSString*)text : (UILabel*)label;
@end

