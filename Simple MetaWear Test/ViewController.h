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
@property NSString *path;
@property NSMutableArray *deviceIdentifiers;
@property (strong,nonatomic) CBCentralManager *bluetoothManager;
@property (weak, nonatomic) IBOutlet UILabel *foundMetaWearsLabels;
@property (weak, nonatomic) IBOutlet UILabel *connectedDevicesLabel;

@property MBLMetaWearManager *manager;

- (IBAction)startSearch:(id)sender; 
- (IBAction)startRecording:(id)sender;
- (IBAction)refreshFoundMetaWearsLabel:(id)sender;
- (void)updateLabel : (NSString*)text : (UILabel*)label;

@end

