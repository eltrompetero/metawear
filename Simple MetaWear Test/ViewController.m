//
//  ViewController.m
//  Simple MetaWear Test
//
//  Created by Eddie on 2/25/16.
//  Copyright © 2016 Eddie. All rights reserved.
//

#import "ViewController.h"
#define SAMPLE_FREQUENCY 200
#define INITIAL_CAPACITY 100000

@implementation ViewController
{
    NSArray *pickerData;
    NSInteger selectedDeviceForFlashing;
}
@synthesize accelerometerDataArrays,gyroDataArrays;
@synthesize foundMetaWearsLabels,connectedDevicesLabel;
@synthesize manager,deviceIdentifiers,deviceInformation;
@synthesize bluetoothManager;
@synthesize devicePicker;
@synthesize scroller;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    scroller.scrollEnabled = YES;
    scroller.userInteractionEnabled = YES;
    scroller.showsVerticalScrollIndicator = YES;
    scroller.showsHorizontalScrollIndicator = YES;
    scroller.contentSize = CGSizeMake(600,600);//width and height depends your scroll area

    
    manager = [MBLMetaWearManager sharedManager];
    self.devicePicker.delegate = self;
    pickerData = @[@"No devices."];
    selectedDeviceForFlashing = -1;
    
    //Allow any number of lines in labels.
    foundMetaWearsLabels.numberOfLines = 0;
    connectedDevicesLabel.numberOfLines = 0;
    
    //Initialize data arrays.
    [self initializeDataArrays];
}

- (void)viewDidAppear:(BOOL) state {
    //Initialize bluetooth manager.
    bluetoothManager = [[CBCentralManager alloc]
                             initWithDelegate:self
                             queue:nil
                             options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0]
                             forKey:CBCentralManagerOptionShowPowerAlertKey]];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    //Check if bluetooth is on and send alert if it isn't.
    if (bluetoothManager.state!=CBCentralManagerStatePoweredOn) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Turn bluetooth on"
                                        message:@"Bluetooth must be activated to find devices."
                                        preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"Settings"
                         style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction *action) {
                             [[UIApplication sharedApplication] openURL: [NSURL URLWithString: UIApplicationOpenSettingsURLString]];
                             }];
        UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close" style:
                                      UIAlertActionStyleDefault handler:nil];
        [alert addAction:closeAction];
        [alert addAction:settingsAction];
        [self presentViewController:alert animated:NO completion:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (int)numberOfComponentsInPickerView:(UIPickerView*) pickerView {
    return 1;
}

- (int)pickerView:(UIPickerView*) pickerView numberOfRowsInComponent:(NSInteger)component {
    return pickerData.count;
}

- (NSString*)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
             forComponent:(NSInteger)component {
    return pickerData[row];
}

// Capture the picker view selection
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    NSLog(@"Selected %ldth device.",(long)row);
    selectedDeviceForFlashing = row;
}

- (IBAction)startSearch:(id)sender {
    //Erase list of devices. This is problematic because it runs asynchronously with the following block of code.
//    [manager retrieveSavedMetaWearsWithHandler:^(NSArray* listOfDevices) {
//        for (MBLMetaWear* device in listOfDevices) {
//            [device forgetDevice];
//        }
//    }];
    
    //Search for devices excluding duplicates.
    //NOTE: Might be a good idea to exclude ones with weak signals.
    [manager startScanForMetaWearsAllowDuplicates:NO handler:^(NSArray *listOfDevices) {
        int i=0;
        
        for (MBLMetaWear *foundDevice in listOfDevices) {
            //NOTE: will need to figure out proper naming scheme without collisions if you don't want to use identifiers
            if ([deviceIdentifiers indexOfObject:foundDevice.identifier.UUIDString]==NSNotFound) {
                [foundDevice rememberDevice];
                [deviceIdentifiers addObject: foundDevice.identifier.UUIDString];
                i++;
            }
        }
        
        // List found metaWears.
        [self updateLabel: [deviceIdentifiers componentsJoinedByString:@"\n"] :foundMetaWearsLabels];
        NSLog(@"MetaWears found:");
        NSLog(@"%@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
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
                    [currdevice readBatteryLifeWithHandler:^(NSNumber *bl,NSError *error) {
                        if (error) {
                            bl = [NSNumber numberWithInt:-1];
                            NSLog(@"Error in reading battery life.");
                        }
                        [deviceInformation addObject: bl];
                    }];
                    [currdevice.led flashLEDColorAsync:[UIColor greenColor] withIntensity:1.0 numberOfFlashes:2];
                }
            }];
        }
        [self refreshFoundMetaWearsLabel:self];
        pickerData = deviceIdentifiers;
        selectedDeviceForFlashing = 0;
        [devicePicker reloadAllComponents];
    }];
}

- (IBAction)refreshFoundMetaWearsLabel:(id)sender {
    NSMutableString *info = [NSMutableString stringWithString: @""];
    [deviceIdentifiers removeAllObjects];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            [deviceIdentifiers addObject:device.identifier.UUIDString];
        }
    }];
    
    if ([deviceIdentifiers count]==[deviceInformation count]) {
        for (int i=0; i<[deviceIdentifiers count]; i++) {
            [info appendFormat: @"%@ (%@)\n",deviceIdentifiers[i],deviceInformation[i]];
        }
        [self updateLabel: info : connectedDevicesLabel];
        NSLog(@"Connected devices %@",info);
    } else {
        [self updateLabel: [deviceIdentifiers componentsJoinedByString:@"\n"] : connectedDevicesLabel];
        NSLog(@"Connected devices %@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
    }
    
    pickerData = deviceIdentifiers;
    selectedDeviceForFlashing = 0;
    [devicePicker reloadAllComponents];
}

- (IBAction)flashDevice:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray* listOfDevices) {
        if (selectedDeviceForFlashing==-1) {
            NSLog(@"Must select a device.");
        } else{
            MBLMetaWear *device = listOfDevices[selectedDeviceForFlashing];
            [device.led flashLEDColorAsync:[UIColor redColor] withIntensity:0.8 numberOfFlashes:3];
        }
    }];
}

- (IBAction)startRecording:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i = 0;
        for (MBLMetaWear *currdevice in listOfDevices) {
            //Initialize arrays for collecting data.
            self.accelerometerDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
            self.gyroDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
            
            //Set accelerometer parameters.
            MBLAccelerometerBMI160 *accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
            MBLGyroBMI160 *gyro = (MBLGyroBMI160*) currdevice.gyro;
            
            accelerometer.sampleFrequency = SAMPLE_FREQUENCY;
            accelerometer.fullScaleRange = MBLAccelerometerBMI160Range4G;
            gyro.sampleFrequency = SAMPLE_FREQUENCY;
            gyro.fullScaleRange = MBLGyroBMI160Range250;
            
            NSLog(@"Starting log of device %d",i);
            [currdevice.accelerometer.dataReadyEvent startNotificationsWithHandlerAsync:^(MBLAccelerometerData *obj, NSError *error) {
                [self.accelerometerDataArrays[i] addObject: @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
            }];
            [currdevice.gyro.dataReadyEvent startNotificationsWithHandlerAsync:^(MBLGyroData *obj,NSError *error) {
                [self.gyroDataArrays[i] addObject: @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
            }];
            i++;
        }
    }];
}

- (IBAction)stopRecording:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i=0;
        for (MBLMetaWear *device in listOfDevices) {
            //Stop streaming data.
            [device.accelerometer.dataReadyEvent stopNotificationsAsync];
            [device.gyro.dataReadyEvent stopNotificationsAsync];
            NSLog(@"Stopping record %i",i);
            i++;
        }
    }];
}

- (IBAction)saveFiles:(id)sender {
    [self stopRecording:self];
    
    NSLog(@"Writing files...");
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        unsigned long int gyroCount,accelCount,count;
        
        for (int i=0; i<[self.accelerometerDataArrays count]; i++) {
            //Combine arrays.
            NSMutableArray *combinedData = [NSMutableArray array];
            //Find longer array and save up to length of shorter array because presumably they are measured at the same time points.
            gyroCount = [self.gyroDataArrays[i] count];
            accelCount = [self.accelerometerDataArrays[i] count];
            if (gyroCount<accelCount) {
                count = gyroCount;
            } else {
                count = accelCount;
            }
            // Columns of [timeStamp,x,y,z,timeStamp,x,y,z].
            for (int j=0;j<count;j++ ) {
                combinedData[j] = @[self.accelerometerDataArrays[i][j][0],
                                    self.accelerometerDataArrays[i][j][1],
                                    self.accelerometerDataArrays[i][j][2],
                                    self.accelerometerDataArrays[i][j][3],
                                    self.gyroDataArrays[i][j][0],
                                    self.gyroDataArrays[i][j][1],
                                    self.gyroDataArrays[i][j][2],
                                    self.gyroDataArrays[i][j][3]];
            }
            
            // Write data to file.
            NSString *path = [documentsDirectory stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"%@.plist",deviceIdentifiers[i]]];
            [combinedData writeToFile:path atomically:YES];
            if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {
                NSLog(@"%@ writable\n",path);
            }else {
                NSLog(@"%@ not writable\n",path);
            }
        }
    }];
    NSLog(@"Done writing.");
}

- (IBAction)disconnectDevices:(id)sender {
    //NOTE: add HUD for preventing user interaction while disconnecting
    //Disconnect.
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            [device disconnectWithHandler:^(NSError* error) {
                if (error) {
                    NSLog(@"Problems disconnecting.");
                }
                else {
                    NSLog(@"Disconnected from %@",device.identifier.UUIDString);
                }
            }];
        };
        [self updateLabel:@"" :connectedDevicesLabel];
    }];
    
    pickerData = @[@"No devices."];
    selectedDeviceForFlashing = 0;
    [devicePicker reloadAllComponents];
}

- (IBAction)exitProgram:(id)sender {
    //Disconnect devices before exiting.
    [self disconnectDevices:self];
    exit(0);
}

/*******************
 Helper functions
********************/

- (void) updateLabel:(NSString*) text : (UILabel*) labelToChange {
    //Compute label size so we can fit all found devices.
    CGSize labelSize = [text sizeWithAttributes:@{NSFontAttributeName:labelToChange.font}];
    labelToChange.frame = CGRectMake( labelToChange.frame.origin.x, labelToChange.frame.origin.y,
                                      labelToChange.frame.size.width, labelSize.height);
    labelToChange.text = text;
}

- (void) initializeDataArrays {
    self.accelerometerDataArrays = [NSMutableArray array];  // Arrays containing logs for each device.
    self.gyroDataArrays = [NSMutableArray array];  // Arrays containing logs for each device.
    self.deviceIdentifiers = [NSMutableArray array];
    self.deviceInformation = [NSMutableArray array];
}

@end

