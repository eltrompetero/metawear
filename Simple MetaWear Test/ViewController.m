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
@synthesize accelerometerDataArrays,gyroDataArrays;
@synthesize foundMetaWearsLabels,connectedDevicesLabel;
@synthesize manager,path,deviceIdentifiers;
@synthesize bluetoothManager;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    manager = [MBLMetaWearManager sharedManager];
    
    //Allow any number of lines in labels.
    foundMetaWearsLabels.numberOfLines = 0;
    connectedDevicesLabel.numberOfLines = 0;
    
    //Initialize data arrays.
    accelerometerDataArrays = [NSMutableArray array];  // Arrays containing logs for each device.
    gyroDataArrays = [NSMutableArray array];  // Arrays containing logs for each device.
    deviceIdentifiers = [NSMutableArray array];
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

- (IBAction)startSearch:(id)sender {
    __block int i=0;
    
    [manager startScanForMetaWearsAllowDuplicates:NO handler:^(NSArray *array) {
        for (MBLMetaWear *foundDevice in array) {
            //Exclude duplicates.
            //NOTE: will need to figure out proper naming scheme without collisions if you don't want to use identifiers
            if ([deviceIdentifiers indexOfObject:foundDevice.identifier.UUIDString]==NSNotFound) {
                [foundDevice rememberDevice];
                NSLog(@"Found device %@",foundDevice);
                [deviceIdentifiers addObject:foundDevice.identifier.UUIDString];
                i++;
            }
        }
        // List found metaWears.
        [self updateLabel:[deviceIdentifiers componentsJoinedByString:@"\n"]:foundMetaWearsLabels];
        
        // Show found devices.
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
                    [currdevice.led flashLEDColorAsync:[UIColor greenColor] withIntensity:1.0 numberOfFlashes:2];
                }
            }];
        }
    }];
}

- (IBAction)refreshFoundMetaWearsLabel:(id)sender {
    [deviceIdentifiers removeAllObjects];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            [deviceIdentifiers addObject:device.identifier.UUIDString];
        }
    }];
    [self updateLabel: [deviceIdentifiers componentsJoinedByString:@"\n"] : connectedDevicesLabel];
    NSLog(@"Connected devices %@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
}

- (IBAction)startRecording:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i = 0;
        for (MBLMetaWear *currdevice in listOfDevices) {
            //Initialize arrays for collecting data.
            accelerometerDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
            gyroDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
            
            //Set accelerometer parameters.
            MBLAccelerometerBMI160 *accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
            MBLGyroBMI160 *gyro = (MBLGyroBMI160*) currdevice.gyro;
            
            accelerometer.sampleFrequency = SAMPLE_FREQUENCY;
            accelerometer.fullScaleRange = MBLAccelerometerBMI160Range4G;
            gyro.sampleFrequency = SAMPLE_FREQUENCY;
            gyro.fullScaleRange = MBLGyroBMI160Range250;
            
            NSLog(@"Starting log of device %d",i);
            [currdevice.accelerometer.dataReadyEvent startNotificationsWithHandlerAsync:^(MBLAccelerometerData *obj, NSError *error) {
                [accelerometerDataArrays[i] addObject: @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
            }];
            [currdevice.gyro.dataReadyEvent startNotificationsWithHandlerAsync:^(MBLGyroData *obj,NSError *error) {
                [gyroDataArrays[i] addObject: @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
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
        unsigned long int gyroCount,accelCount,count;
        
        for (MBLMetaWear *device in listOfDevices) {
            [device.accelerometer.dataReadyEvent stopNotificationsAsync];
            [device.gyro.dataReadyEvent stopNotificationsAsync];
            
            //Combine arrays.
            NSMutableArray *combinedData = [NSMutableArray array];
            //Find longer array
            gyroCount = [gyroDataArrays[i] count];
            accelCount = [accelerometerDataArrays[i] count];
            if (gyroCount<accelCount) {
                count = gyroCount;
            } else {
                count = accelCount;
            }
            // Columns of [timeStamp,x,y,z,timeStamp,x,y,z].
            for (int j=0;j<count;j++ ) {
                combinedData[j] = @[accelerometerDataArrays[i][j][0],
                                    accelerometerDataArrays[i][j][1],
                                    accelerometerDataArrays[i][j][2],
                                    accelerometerDataArrays[i][j][3],
                                    gyroDataArrays[i][j][0],
                                    gyroDataArrays[i][j][1],
                                    gyroDataArrays[i][j][2],
                                    gyroDataArrays[i][j][3]];
            }
            
            // Write data to file.
            path = [documentsDirectory stringByAppendingPathComponent:
                                            [NSString stringWithFormat:@"accel_output%d.plist",i]];
            [combinedData writeToFile:path atomically:YES];
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

@end

