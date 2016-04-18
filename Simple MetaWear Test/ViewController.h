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
@property (strong, nonatomic) NSMutableArray *accelerometerDataArrays;
@property (strong, nonatomic) NSMutableArray *gyroDataArrays;
@property NSMutableArray *deviceIdentifiers;
@property NSMutableArray *deviceInformation;
@property (strong, atomic) CBCentralManager *bluetoothManager;
@property (weak, nonatomic) IBOutlet UILabel *connectedDevicesLabel;

@property (weak, nonatomic) IBOutlet UITableView *selectDevicesTable;
@property (weak, nonatomic) IBOutlet UIPickerView *devicePicker;
@property (weak, nonatomic) IBOutlet UIScrollView *scroller;
@property (weak, nonatomic) IBOutlet UILabel *sampleFrequencyLabel;
@property (weak, nonatomic) IBOutlet UISlider *sampleFrequencySlider;
@property (weak, nonatomic) IBOutlet UILabel *downloadProgressAccel;
@property (weak, nonatomic) IBOutlet UILabel *downloadProgressGyro;


@property MBLMetaWearManager *manager;

- (IBAction)startSearch:(id)sender; 
- (IBAction)startRecording:(id)sender;

- (IBAction)refreshConnectedMetaWearsLabel:(id)sender;
- (IBAction)flashDevice:(id)sender;
- (void)centralManagerDidUpdateState:(CBCentralManager *)central;

- (IBAction)stopRecording:(id)sender;
- (IBAction)disconnectDevices:(id)sender;
- (IBAction)exitProgram:(id)sender;

- (void)updateLabel : (NSString*)text : (UILabel*)label;
@end

