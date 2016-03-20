//
//  ViewController.m
//  Simple MetaWear Test
//
//  Created by Eddie on 2/25/16.
//  Copyright © 2016 Eddie. All rights reserved.
//

#import "ViewController.h"
#import <MetaWear/MetaWear.h>

@implementation ViewController
@synthesize accelerometerDataArrays;
@synthesize listOfFoundMetaWears,connectedDevicesLabel;
@synthesize manager,path;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    manager = [MBLMetaWearManager sharedManager];
    
    //Allow any number of lines in labels.
    listOfFoundMetaWears.numberOfLines = 0;
    connectedDevicesLabel.numberOfLines = 0;
    
    accelerometerDataArrays = [NSMutableArray array];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startSearch:(id)sender {
    __block NSMutableString *metaWearNames = [NSMutableString stringWithString: @""];
    __block int i=0;
    
    [manager startScanForMetaWearsAllowDuplicates:NO handler:^(NSArray *array) {
        for (MBLMetaWear *foundDevice in array) {
            //Exclude duplicates.
            //NOTE: will need to figure out propery naming scheme without collisions
            if ([metaWearNames containsString:foundDevice.identifier.UUIDString]==NO) {
                [foundDevice rememberDevice];
                NSLog(@"Found device %@",foundDevice);
//                foundDevice.name = [NSString stringWithFormat:@"Device_%d",i];
                [metaWearNames appendString: [@"\n" stringByAppendingString: foundDevice.identifier.UUIDString]];
                i++;
            }
        }
        
        [self updateLabel:metaWearNames:listOfFoundMetaWears];
        
        // Show found devices.
        NSLog(@"MetaWears found:");
        NSLog(@"%@",metaWearNames);
    }];
}
- (IBAction)connectToDevices:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *array) {
        for (MBLMetaWear *currdevice in array) {
            // Connect to the device first.
            // connectWithTimeout:handler: is a simple way to limit the amount of
            // time spent searching for the device
            [currdevice connectWithTimeout:20 handler:^(NSError *error) {
                if ([error.domain isEqualToString:kMBLErrorDomain] &&
                    error.code == kMBLErrorConnectionTimeout) {
                    [currdevice forgetDevice];
                    NSLog(@"Connection Timeout");
                }
                else {
                    NSLog(@"Connection succeeded with %@.",currdevice.identifier.UUIDString);
                    [currdevice.led flashLEDColorAsync:[UIColor greenColor] withIntensity:1.0 numberOfFlashes:2];
                }
            }];
        }
    }];
}

- (IBAction)startRecording:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i=0;
        for (MBLMetaWear *device in listOfDevices) {
            accelerometerDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:1000];
            
            NSLog(@"Starting log %d.",i);
            device.accelerometer.sampleFrequency = 100; // Default: 100 Hz
            
            MBLEvent *event = device.accelerometer.dataReadyEvent;
            [event startNotificationsWithHandlerAsync:^(MBLAccelerometerData *obj, NSError *error) {
//                NSLog(@"X = %f, Y = %f, Z = %f", obj.x, obj.y, obj.z);
                accelerometerDataArrays[i] = @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)];
            }];
            i++;
        }
    }];
}

- (IBAction)stopRecording:(id)sender {
    NSLog(@"Writing files...");
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i=0;
        for (MBLMetaWear *device in listOfDevices) {
            [device.accelerometer.dataReadyEvent stopNotificationsAsync];
            
            // Write data to file.
            path = [documentsDirectory stringByAppendingPathComponent:
                                            [NSString stringWithFormat:@"accel_output%d.plist",i]];
            [accelerometerDataArrays[i] writeToFile:path atomically:YES];
            if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {
                NSLog(@"%@ writable",path);
            }else {
                NSLog(@"%@ not writable",path);
            }
            
            i++;
        }
    }];
    NSLog(@"Done writing.");
}

- (void) updateLabel:(NSMutableString*) text : (UILabel*) labelToChange {
    //Compute label size so we can fit all found devices.
    CGSize labelSize = [text sizeWithAttributes:@{NSFontAttributeName:labelToChange.font}];
    labelToChange.frame = CGRectMake( labelToChange.frame.origin.x, labelToChange.frame.origin.y,
                                      labelToChange.frame.size.width, labelSize.height);
    labelToChange.text = text;
}
@end

