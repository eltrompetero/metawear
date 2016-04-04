//
//  ViewController.m
//  Simple MetaWear Test
//
//  Created by Eddie on 2/25/16.
//  Copyright © 2016 Eddie. All rights reserved.
//

#import "ViewController.h"
#import "MBProgressHUD.h"
#import "SmallTableViewController.h"
#define INITIAL_CAPACITY 20000
#define DEFAULT_SAMPLE_FREQUENCY 20

@implementation ViewController
{
    NSArray *pickerData;
    int sampleFrequency;
    NSMutableArray *connectedDevices;
}
@synthesize accelerometerDataArrays,gyroDataArrays;
@synthesize connectedDevicesLabel;
@synthesize manager,deviceIdentifiers,deviceInformation;
@synthesize bluetoothManager;
@synthesize devicePicker;
@synthesize scroller;
@synthesize downloadProgressBar;


/*************************
 View controller delegate
 *************************/
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    scroller.scrollEnabled = YES;
    scroller.userInteractionEnabled = YES;
    scroller.showsVerticalScrollIndicator = YES;
    scroller.contentSize = CGSizeMake(350,2000);//width and height depends your scroll area
    
    _selectDevicesTable.allowsMultipleSelection=YES;
    [_selectDevicesTable setDelegate:self];
    [_selectDevicesTable setDataSource:self];
    
    [_sampleFrequencySlider setValue:20];
    [_sampleFrequencySlider setMaximumValue:100];
    [_sampleFrequencySlider setMinimumValue:1];
    [_sampleFrequencyLabel setText:[NSString stringWithFormat:@"%d",DEFAULT_SAMPLE_FREQUENCY]];
    sampleFrequency=DEFAULT_SAMPLE_FREQUENCY;
    
    manager = [MBLMetaWearManager sharedManager];
    self.devicePicker.delegate = self;
    pickerData = @[@"No devices."];
    
    //Allow any number of lines in labels.
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
    [_selectDevicesTable reloadData];
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


/*******************
 Table delegate
 ********************/
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [tableView cellForRowAtIndexPath:indexPath];
    tableViewCell.accessoryView.hidden = NO;
    // if you don't use a custom image then tableViewCell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *tableViewCell = [tableView cellForRowAtIndexPath:indexPath];
    tableViewCell.accessoryView.hidden = YES;
    // if you don't use a custom image then tableViewCell.accessoryType = UITableViewCellAccessoryNone;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    // If You have only one(1) section, return 1, otherwise you must handle sections
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [deviceIdentifiers count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    cell.textLabel.text = [NSString stringWithFormat:@"%@",[deviceIdentifiers objectAtIndex:indexPath.row]];
    
    return cell;
}


/*******************
 Picker delegate
 ********************/
- (int)numberOfComponentsInPickerView:(UIPickerView*) pickerView {
    return 1;
}

- (int)pickerView:(UIPickerView*) pickerView numberOfRowsInComponent:(NSInteger)component {
    return (int)pickerData.count;
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
}

- (void)refresh_picker {
    if ([connectedDevices count]>0) {
        pickerData = connectedDevices;
        NSLog(@"Picker connected devices %@",[connectedDevices componentsJoinedByString:@"\n"]);
        [devicePicker reloadAllComponents];
    }
}


/*******************
       Buttons
 ********************/
- (IBAction)startSearch:(id)sender {
    //Erase list of devices. This is problematic because it runs asynchronously with the following block of code.
//    [manager retrieveSavedMetaWearsWithHandler:^(NSArray* listOfDevices) {
//        for (MBLMetaWear* device in listOfDevices) {
//            [device forgetDevice];
//        }
//    }];
    MBProgressHUD *hud = [self busyIndicator:@"Searching..."];
    
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
        NSLog(@"MetaWears found:");
        NSLog(@"%@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
        [hud hide:YES afterDelay:0.5];
        [_selectDevicesTable reloadData];
    }];
}

- (IBAction)connectToDevices:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Connecting..."];
    NSArray *indexPathArray = [_selectDevicesTable indexPathsForSelectedRows];
    NSMutableArray *selectedDeviceIdentifiers = [[NSMutableArray alloc] init];
    [connectedDevices removeAllObjects];
    
    // Get the devices that have been selected for connection.
    NSLog(@"Devices selected for connection are at following rows:");
    for (NSIndexPath *i in indexPathArray) {
        NSLog(@"%d",(int)i.row);
        [selectedDeviceIdentifiers addObject: [deviceIdentifiers objectAtIndex:i.row]];
    }
    
    // Only connected to selected devices.
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *array) {
        for (MBLMetaWear *currdevice in array) {
            // Connect to the device first.
            // connectWithTimeout:handler: is a simple way to limit the amount of
            // time spent searching for the device
            if ([selectedDeviceIdentifiers containsObject:currdevice.identifier.UUIDString]) {
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
                        [connectedDevices addObject:currdevice.identifier.UUIDString];
                    }
                }];
                [self refreshConnectedMetaWearsLabel:self];
            }//endif
        }
        
        [self refresh_picker];
        [hud hide:YES afterDelay:5.];
    }];
}

- (IBAction)refreshConnectedMetaWearsLabel:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Refreshing..."];
    [deviceIdentifiers removeAllObjects];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            [deviceIdentifiers addObject:device.identifier.UUIDString];
        }
        NSLog(@"Connected devices %@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
    }];
    
    // Update list of connected devices in label.
    [self updateLabel: [connectedDevices componentsJoinedByString:@"\n"] : connectedDevicesLabel];
    NSLog(@"Connected devices after update %@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
    [hud hide:YES afterDelay:.5];
    [self refresh_picker];
}

- (IBAction)change_sample_frequency:(id)sender {
    sampleFrequency = (int) self.sampleFrequencySlider.value;
    // Don't allow sample frequency to exceed 100 Hz.
    if (([connectedDevices count]*sampleFrequency) > 100) {
        sampleFrequency = (int) 100/[connectedDevices count];
    }
    
    [_sampleFrequencySlider setValue:sampleFrequency animated:YES];
    [_sampleFrequencyLabel setText:[NSString stringWithFormat:@"%d",sampleFrequency]];
}

- (IBAction)flashDevice:(id)sender {
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray* listOfDevices) {
        if ([self.devicePicker selectedRowInComponent:0]==-1) {
            NSLog(@"Must select a device.");
        } else{
            // Collect the id's of the devices in the array.
            NSMutableArray *theseids = [NSMutableArray array];
            for (MBLMetaWear *l in listOfDevices) {
                [theseids addObject:l.identifier.UUIDString];
            }
            
            // See if this device is in the connected devices array.
            NSInteger connectedDevicesIx = [self.devicePicker selectedRowInComponent:0];
            NSUInteger idx = [theseids indexOfObject:connectedDevices[connectedDevicesIx]];
            
            NSLog(@"Flashing %@",theseids[idx]);
            MBLMetaWear *device = listOfDevices[idx];
            [device.led flashLEDColorAsync:[UIColor redColor] withIntensity:0.8 numberOfFlashes:3];
        }
    }];
}

- (IBAction)startRecording:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Starting..."];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i = 0;
        for (MBLMetaWear *currdevice in listOfDevices) {
            if ([connectedDevices indexOfObject:currdevice.identifier.UUIDString]!=NSNotFound) {
                //Initialize arrays for collecting data.
                self.accelerometerDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
                self.gyroDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
                
                //Set accelerometer parameters.
                MBLAccelerometerBMI160 *accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
                MBLGyroBMI160 *gyro = (MBLGyroBMI160*) currdevice.gyro;
                
                accelerometer.sampleFrequency = sampleFrequency;
                accelerometer.fullScaleRange = MBLAccelerometerBMI160Range4G;
                gyro.sampleFrequency = sampleFrequency;
                gyro.fullScaleRange = MBLGyroBMI160Range500;
                
                NSLog(@"Starting log of device %d",i);
                [currdevice.accelerometer.dataReadyEvent startNotificationsWithHandlerAsync:^(MBLAccelerometerData *obj, NSError *error) {
                    if (error) {
                        NSLog(@"Error in accelerometer data.");
                        [self disconnectedAlert:currdevice.identifier.UUIDString];
                        [self.accelerometerDataArrays[i] addObject:@[@"NaN",@"NaN",@"NaN",@"NaN"]];
                    } else {
                        [self.accelerometerDataArrays[i] addObject:
                                @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
                    }
                }];
                [currdevice.gyro.dataReadyEvent startNotificationsWithHandlerAsync:^(MBLGyroData *obj,NSError *error) {
                    if (error) {
                        NSLog(@"Error in gyrometer data.");
                        [self.gyroDataArrays[i] addObject: @[@"NaN",@"NaN",@"NaN",@"NaN"]];
                    } else {
                        [self.gyroDataArrays[i] addObject: @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
                    }
                }];
                i++;
            }//endif
        }
        [hud hide:YES afterDelay:0.5];
    }];
}

- (IBAction)stopRecording:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Stopping..."];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i=0;
        for (MBLMetaWear *device in listOfDevices) {
            //Stop streaming data.
            if ([connectedDevices indexOfObject:device.identifier.UUIDString]!=NSNotFound) {
                [device.accelerometer.dataReadyEvent stopNotificationsAsync];
                [device.gyro.dataReadyEvent stopNotificationsAsync];
                NSLog(@"Stopping record %i",i);
                i++;
            }
        }
        
        [hud hide:YES afterDelay:0.5];
    }];
}


- (IBAction)startLogRecording:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Starting..."];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i = 0;
        for (MBLMetaWear *currdevice in listOfDevices) {
            if ([connectedDevices indexOfObject:currdevice.identifier.UUIDString]!=NSNotFound) {
                //Initialize arrays for collecting data.
                self.accelerometerDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
                self.gyroDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
                
                //Set accelerometer parameters.
                MBLAccelerometerBMI160 *accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
                MBLGyroBMI160 *gyro = (MBLGyroBMI160*) currdevice.gyro;
                
                accelerometer.sampleFrequency = sampleFrequency;
                accelerometer.fullScaleRange = MBLAccelerometerBMI160Range4G;
                gyro.sampleFrequency = sampleFrequency;
                gyro.fullScaleRange = MBLGyroBMI160Range500;
                
                NSLog(@"Starting log of device %d",i);
                [currdevice.accelerometer.dataReadyEvent startLoggingAsync];
                [currdevice.gyro.dataReadyEvent startLoggingAsync];
                i++;
            }
        }
        [hud hide:YES afterDelay:0.5];
    }];
}

- (IBAction)stopLogRecording:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Stopping..."];
    
    [manager retrieveSavedMetaWearsWithHandler:^(NSArray *listOfDevices) {
        int i=0;
        for (MBLMetaWear *device in listOfDevices) {
            if ([connectedDevices indexOfObject:device.identifier.UUIDString]!=NSNotFound) {
                //Stop streaming data and store in local data arrays.
                [[device.accelerometer.dataReadyEvent downloadLogAndStopLoggingAsync:YES progressHandler:^(float number) {
                    // Update progress bar, as this can take upwards of one minute to download a full log
                    [self.downloadProgressBar setText:[NSString stringWithFormat:@"%f",number*100]];
                }] success:^(NSArray<MBLNumericData *> * _Nonnull result) {
                    // array contains all the log entries
                    for (MBLNumericData *entry in result) {
                        [self.accelerometerDataArrays[i] addObject:entry];
                    }
                }];
                
                [[device.gyro.dataReadyEvent downloadLogAndStopLoggingAsync:YES progressHandler:^(float number) {
                    // Update progress bar using accelerometer data.
                }] success:^(NSArray<MBLNumericData *> * _Nonnull result) {
                    // array contains all the log entries
                    for (MBLNumericData *entry in result) {
                        [self.gyroDataArrays[i] addObject:entry];
                    }
                }];
                
                NSLog(@"Stopping record %i",i);
                i++;
            }
        }
        
        [hud hide:YES afterDelay:0.5];
    }];
}



- (IBAction)saveFiles:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Saving..."];
    
    [self stopRecording:self];
    
    NSLog(@"Writing files...");
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS"];
    
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
                combinedData[j] =@[
                    [dateFormatter stringFromDate:self.accelerometerDataArrays[i][j][0]],
                    self.accelerometerDataArrays[i][j][1],
                    self.accelerometerDataArrays[i][j][2],
                    self.accelerometerDataArrays[i][j][3],
                    [dateFormatter stringFromDate:self.gyroDataArrays[i][j][0]],
                    self.gyroDataArrays[i][j][1],
                    self.gyroDataArrays[i][j][2],
                    self.gyroDataArrays[i][j][3]
                    ];
            }
            
            // Write data to file.
            NSString *path = [documentsDirectory stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"%@_sample%d.plist",
                     deviceIdentifiers[i],sampleFrequency]];
            [combinedData writeToFile:path atomically:YES];
            if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {
                NSLog(@"%@ writable\n",path);
            }else {
                NSLog(@"%@ not writable\n",path);
            }
        }
        [hud hide:YES afterDelay:0.5];
    }];
    NSLog(@"Done writing.");
}

- (IBAction)disconnectDevices:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Disconnecting..."];
    [connectedDevices removeAllObjects];
    
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
    [devicePicker reloadAllComponents];
    [self clearTable];
    [hud hide:YES afterDelay:0.5];
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
    connectedDevices = [NSMutableArray array];
}

- (MBProgressHUD *)busyIndicator:(NSString *)message {
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
    hud.mode = MBProgressHUDModeText;
    hud.userInteractionEnabled=NO;
    hud.dimBackground=YES;
    hud.labelText = message;
    return hud;
}

- (void)disconnectedAlert:(NSString*)deviceId {
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"Device disconnected"
                                message:deviceId
                                preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close" style:
                                  UIAlertActionStyleDefault handler:nil];
    [alert addAction:closeAction];
    [self presentViewController:alert animated:NO completion:nil];
}

- (void)clearTable {
    for (NSIndexPath *i in [_selectDevicesTable indexPathsForSelectedRows]) {
        [_selectDevicesTable deselectRowAtIndexPath:i animated:NO];
    }
}

- (NSMutableArray*)get_ids:(NSArray*)listOfDevices {
    NSMutableArray *thisids = [NSMutableArray array];
    for (MBLMetaWear *l in listOfDevices) {
        [thisids addObject: l.identifier.UUIDString];
    }
    return thisids;
}

@end

