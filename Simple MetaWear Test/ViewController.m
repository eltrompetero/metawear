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
    NSArray<MBLMetaWear *> *connectedDevicesFrontEnds;
}
@synthesize accelerometerDataArrays,gyroDataArrays;
@synthesize connectedDevicesLabel;
@synthesize manager,deviceIdentifiers,deviceInformation;
@synthesize bluetoothManager;
@synthesize devicePicker;
@synthesize scroller;
@synthesize downloadProgressAccel;
@synthesize downloadProgressGyro;


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
    [_sampleFrequencyTextField setText:[NSString stringWithFormat:@"%d",DEFAULT_SAMPLE_FREQUENCY]];
    sampleFrequency=DEFAULT_SAMPLE_FREQUENCY;
    
    manager = [MBLMetaWearManager sharedManager];
    self.devicePicker.delegate = self;
    pickerData = @[@"No devices."];
    
    //Allow any number of lines in labels.
    connectedDevicesLabel.numberOfLines = 0;
    
    //Initialize data arrays.
    [self initialize_info_arrays];
    
    _sampleFrequencyTextField.keyboardType = UIKeyboardTypeNumberPad;
}

- (void)viewDidAppear:(BOOL) state {
    //Initialize bluetooth manager.
    bluetoothManager = [[CBCentralManager alloc]
                             initWithDelegate:self
                             queue:nil
                             options:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0]
                             forKey:CBCentralManagerOptionShowPowerAlertKey]];
    [_selectDevicesTable reloadData];
    
    // Disable some buttons.
    [self disable_button:_stopRecordingButton];
    [self disable_button:_stopLoggingButton];
    [self disable_button:_connectDevicesButton];
    [self disable_button:_resetLoggingButton];
    [self disable_button:_refreshListButton];
    [self disable_button:_flashRed];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    //Check if bluetooth is on and show alert with button to settings if it isn't.
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

- (IBAction)refresh_picker:(id)sender {
    if ([connectedDevices count]>0) {
        pickerData = connectedDevices;
        NSLog(@"Picker connected devices %@",[connectedDevices componentsJoinedByString:@"\n"]);
        [devicePicker reloadAllComponents];
        [self enable_button:_flashRed];
    }
}



/*******************
 Sample frequency text.
 ********************/
- (IBAction)show_number_pad:(id)sender {
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleBlackTranslucent;
    numberToolbar.items = @[[[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
                            [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc]initWithTitle:@"Apply" style:UIBarButtonItemStyleDone target:self action:@selector(doneWithNumberPad)]];
    [numberToolbar sizeToFit];
    _sampleFrequencyTextField.inputAccessoryView = numberToolbar;
}

-(void)cancelNumberPad{
    [_sampleFrequencyTextField resignFirstResponder];
    _sampleFrequencyTextField.text = @"";
}

-(void)doneWithNumberPad{
    [_sampleFrequencyTextField resignFirstResponder];
}

- (IBAction)update_sample_frequency:(id)sender {
    sampleFrequency = [_sampleFrequencyTextField.text intValue];
    self.sampleFrequencySlider.value = sampleFrequency;
}

- (IBAction)change_sample_frequency:(id)sender {
    sampleFrequency = (int) self.sampleFrequencySlider.value;
    // Don't allow sample frequency to exceed 100 Hz.
    if (([connectedDevices count]*sampleFrequency) > 100) {
        sampleFrequency = (int) 100/[connectedDevices count];
    }
    
    [_sampleFrequencySlider setValue:sampleFrequency animated:YES];
    [_sampleFrequencyTextField setText:[NSString stringWithFormat:@"%d",sampleFrequency]];
}


/*******************
       Buttons
 ********************/
- (IBAction)clearSavedDevices:(id)sender {
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *array) {
        for (MBLMetaWear* device in array) {
            NSLog(@"Delete device %@",device.name);
            [device forgetDevice];
        }
        [deviceIdentifiers removeAllObjects];
    }];
}

- (IBAction)startSearch:(id)sender {
    [self disable_button:_connectDevicesButton];
    [self disable_button:_refreshListButton];
    MBProgressHUD *hud = [self busyIndicator:@"Searching..."];
    
    //Search for devices excluding duplicates.
    //NOTE: Might be a good idea to exclude ones with weak signals.
    [manager startScanForMetaWearsAllowDuplicates:NO handler:^(NSArray *listOfDevices) {
        for (MBLMetaWear *foundDevice in listOfDevices) {
            //NOTE: will need to figure out proper naming scheme without collisions if you don't
            //want to use identifiers
            if (![deviceIdentifiers containsObject:foundDevice.name]) {
                [foundDevice rememberDevice];
                [deviceIdentifiers addObject: foundDevice.name];
            }
        }
        
        [self enable_button:_connectDevicesButton];
        [self enable_button:_refreshListButton];
        
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
    
    // Get the devices that have been selected for connection.
    NSLog(@"Devices selected for connection are at following rows:");
    for (NSIndexPath *i in indexPathArray) {
        NSLog(@"%d",(int)i.row);
        [selectedDeviceIdentifiers addObject: [deviceIdentifiers objectAtIndex:i.row]];
    }
    
    // Only connected to selected devices that have not yet been connected.
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *array) {
        for (MBLMetaWear *currdevice in array) {
            // Connect to the device first.
            if ([selectedDeviceIdentifiers containsObject:currdevice.name] &&
                [connectedDevices containsObject:currdevice.name]==NO) {
                [currdevice connectWithTimeout:30 handler:^(NSError *error) {
                    if ([error.domain isEqualToString:kMBLErrorDomain] &&
                        error.code == kMBLErrorConnectionTimeout) {
                        [self popup_title:@"Could not connect"
                                  message:currdevice.name];
                        [currdevice forgetDevice];
                        NSLog(@"Connection Timeout");
                    }
                    else {
                        NSLog(@"Connection succeeded with %@.",currdevice.name);
                        [currdevice readBatteryLifeWithHandler:^(NSNumber *bl,NSError *error) {
                            if (error) {
                                bl = [NSNumber numberWithInt:-1];
                                NSLog(@"Error in reading battery life.");
                            }
                            [deviceInformation addObject: bl];
                        }];
                        [currdevice.led flashLEDColorAsync:[UIColor greenColor] withIntensity:1.0 numberOfFlashes:2];
                        [connectedDevices addObject:currdevice.name];
                        //Increase transmit power.
                        currdevice.settings.transmitPower = MBLTransmitPower4dBm;
                    }
                }];
            }//endif
        }
        [self refreshConnectedMetaWearsLabel:self];
        [self change_sample_frequency:self];
        [hud hide:YES afterDelay:5.];
    }];
    [self clearTable];
}

- (IBAction)refreshConnectedMetaWearsLabel:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Refreshing..."];
    [deviceIdentifiers removeAllObjects];
    
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            [deviceIdentifiers addObject:device.name];
        }
        NSLog(@"Connected devices %@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
    }];
    
    // Update list of connected devices in label.
    [self updateLabel: [connectedDevices componentsJoinedByString:@"\n"] : connectedDevicesLabel];
    NSLog(@"Connected devices after update %@",[deviceIdentifiers componentsJoinedByString:@"\n"]);
    [_selectDevicesTable reloadData];
    [hud hide:YES afterDelay:.5];
    [self refresh_picker:self];
}


- (IBAction)flashDevice:(id)sender {
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray* listOfDevices) {
        if ([self.devicePicker selectedRowInComponent:0]==-1) {
            NSLog(@"Must select a device.");
        } else{
            // Collect the id's of the devices in the array.
            NSMutableArray *theseids = [NSMutableArray array];
            for (MBLMetaWear *l in listOfDevices) {
                [theseids addObject:l.name];
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
    [self initialize_data_arrays];
    _logLabel.text=@"";
    _logLabel.numberOfLines=[connectedDevices count];
    NSMutableArray* logStrings = [NSMutableArray array];
    
    if ([self checkForConnectedDevices]) {
        MBProgressHUD *hud = [self busyIndicator:@"Starting..."];
        
        [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
            int ix;
            MBLAccelerometerBMI160 *accelerometer;
            MBLGyroBMI160 *gyro;
            NSString* s;
            
            for (MBLMetaWear *currdevice in listOfDevices) {
                if ([connectedDevices containsObject:currdevice.name]) {
                    ix = (int) [connectedDevices indexOfObject:currdevice.name];
                    
                    //Set accelerometer parameters.
                    accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
                    gyro = (MBLGyroBMI160*) currdevice.gyro;
                    
                    accelerometer.sampleFrequency = sampleFrequency;
                    accelerometer.fullScaleRange = MBLAccelerometerBoschRange4G;
                    gyro.sampleFrequency = sampleFrequency;
                    gyro.fullScaleRange = MBLGyroBMI160Range500;
                    
                    NSLog(@"Starting log of device %d",ix);
                    [currdevice.led flashLEDColorAsync:[UIColor blueColor]
                                         withIntensity:0.8
                                       numberOfFlashes:5];
                    
                    [currdevice.accelerometer.dataReadyEvent
                     startNotificationsWithHandlerAsync:^(MBLAccelerometerData *obj, NSError *error) {
                        if (error) {
                            NSLog(@"Error in accelerometer data.");
                            [self disconnectedAlert:currdevice.name];
                            [self.accelerometerDataArrays[ix] addObject:@[@"NaN",@"NaN",@"NaN",@"NaN"]];
                        } else {
                            [self.accelerometerDataArrays[ix] addObject:
                                    @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
                        }
                    }];
                    [currdevice.gyro.dataReadyEvent
                     startNotificationsWithHandlerAsync:^(MBLGyroData *obj,NSError *error) {
                        if (error) {
                            NSLog(@"Error in gyrometer data.");
                            [self.gyroDataArrays[ix] addObject: @[@"NaN",@"NaN",@"NaN",@"NaN"]];
                        } else {
                            [self.gyroDataArrays[ix] addObject:
                                    @[obj.timestamp,@(obj.x),@(obj.y),@(obj.z)]];
                        }
                    }];
                    
                    s = [NSString stringWithFormat:@"%@: Accel %d, Gyro %d",
                        currdevice.name,
                        [currdevice.accelerometer.dataReadyEvent isNotifying],
                        [currdevice.gyro.dataReadyEvent isNotifying]];
                    [logStrings addObject:[_logLabel.text stringByAppendingString:s]];
                    NSLog(@"Device %@ is notifying? Accel %d, Gyro %d",currdevice.name,
                          [currdevice.accelerometer.dataReadyEvent isNotifying],
                          [currdevice.gyro.dataReadyEvent isNotifying]);
                }//endif
            }
            [hud hide:YES afterDelay:0.5];
            _logLabel.text = [logStrings componentsJoinedByString:@"\n"];
            [self disable_button:_startRecordingButton];
            [self enable_button:_stopRecordingButton];
        }];
    }
}

- (IBAction)stopRecording:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Stopping..."];
    _logLabel.text=@"";
    _logLabel.numberOfLines=[connectedDevices count];
    NSMutableArray* logStrings = [NSMutableArray array];
    
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
        int i=0;
        NSString* s;
        for (MBLMetaWear *device in listOfDevices) {
            //Stop streaming data.
            if ([connectedDevices containsObject:device.name]) {
                [device.led flashLEDColorAsync:[UIColor redColor]
                                 withIntensity:0.8
                               numberOfFlashes:5];
            
                [device.accelerometer.dataReadyEvent stopNotificationsAsync];
                [device.gyro.dataReadyEvent stopNotificationsAsync];
                
                s = [NSString stringWithFormat:@"%@: Accel %d, Gyro %d",
                     device.name,
                     [device.accelerometer.dataReadyEvent isNotifying],
                     [device.gyro.dataReadyEvent isNotifying]];
                [logStrings addObject:[_logLabel.text stringByAppendingString:s]];
                
                NSLog(@"Device %@ is notifying? Accel %d, Gyro %d",device.name,
                      [device.accelerometer.dataReadyEvent isNotifying],
                      [device.gyro.dataReadyEvent isNotifying]);
                NSLog(@"Stopping record %i",i);
                i++;
            }
        }
        
        [hud hide:YES afterDelay:0.5];
        _logLabel.text = [logStrings componentsJoinedByString:@"\n"];
        [self disable_button:_stopRecordingButton];
        [self enable_button:_startRecordingButton];
    }];
}


- (IBAction)resetLogging:(id)sender {
    // Check if there are any connected devices.
    if ([self checkForConnectedDevices]) {
        MBProgressHUD *hud = [self busyIndicator:@"Starting..."];
        [self clear_device_logs];
        [hud hide:YES];
    } else {
        //Show popup.
    }
    [self disable_button:_resetLoggingButton];
    [self enable_button:_startLoggingButton];
}


-(void)clear_device_logs {
    // Iterate through connected devices and stop logging and clear logs.
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
        for (MBLMetaWear *currdevice in listOfDevices) {
            if ([connectedDevices containsObject:currdevice.name]) {
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow
                                                          animated:YES];
                [currdevice.led flashLEDColorAsync:[UIColor blueColor]
                                     withIntensity:0.8
                                   numberOfFlashes:1];
                [currdevice.led flashLEDColorAsync:[UIColor greenColor]
                                     withIntensity:0.8
                                   numberOfFlashes:1];
                
                
                hud.mode = MBProgressHUDModeIndeterminate;
                hud.labelText = @"Clearing Log...";
                [[[currdevice.accelerometer.dataReadyEvent downloadLogAndStopLoggingAsync:YES
                                                                          progressHandler:^(float number) {
                          // Update progress bar, as this can take upwards of one minute to download a full log
                          [self.downloadProgressAccel setText:[NSString stringWithFormat:@"%f",number*100]];
                      }] success:^(NSArray<MBLNumericData *> * _Nonnull result) {
                          [self logCleanup:currdevice handler:^(NSError *error) {
                              if (error) {
                                  NSLog(@"Error clearing log.");
                                  [hud hide:YES];
                              } else {
                                  NSLog(@"Success clearing log.");
                                  [hud hide:YES];
                              }
                          }];
                      }] failure:^(NSError * _Nonnull error) {
                          NSLog(@"Failed to stop logging. Is device still connected?");
                          [hud hide:YES];
                      }];
            }//endif
        }//endfor
    }];
}


- (IBAction)set_settings:(id)sender {
    // Check if there are any connected devices.
    if ([self checkForConnectedDevices]) {
        
        [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
            int ix;
            MBLAccelerometerBMI160 *accelerometer;
            MBLGyroBMI160 *gyro;
            
            for (MBLMetaWear *currdevice in listOfDevices) {
                if ([connectedDevices containsObject:currdevice.name]) {
                    ix = (int) [connectedDevices indexOfObject:currdevice.name];
                    NSLog(@"Setting device %@ to sample frequency %d",
                          [connectedDevices objectAtIndex:ix],sampleFrequency);
                    currdevice.settings.circularBufferLog=YES;
                    
                    //Set accelerometer parameters.
                    accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
                    gyro = (MBLGyroBMI160*) currdevice.gyro;
                    
                    accelerometer.sampleFrequency = sampleFrequency;
                    accelerometer.fullScaleRange = MBLAccelerometerBoschRange4G;
                    gyro.sampleFrequency = sampleFrequency;
                    gyro.fullScaleRange = MBLGyroBMI160Range500;
                }
            }
        }];
    }
}


- (IBAction)startLogRecording:(id)sender {
    [self initialize_data_arrays];
    
    // Check if there are any connected devices.
    if ([self checkForConnectedDevices]) {
        MBProgressHUD *hud = [self busyIndicator:@"Starting..."];
        
        [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
            int ix;
            for (MBLMetaWear *currdevice in listOfDevices) {
                if ([connectedDevices containsObject:currdevice.name]) {
                    ix = (int) [connectedDevices indexOfObject:currdevice.name];
                    currdevice.settings.circularBufferLog=YES;
                    
                    //Set accelerometer parameters.
                    MBLAccelerometerBMI160 *accelerometer = (MBLAccelerometerBMI160*) currdevice.accelerometer;
                    MBLGyroBMI160 *gyro = (MBLGyroBMI160*) currdevice.gyro;
                    
                    accelerometer.sampleFrequency = sampleFrequency;
                    accelerometer.fullScaleRange = MBLAccelerometerBoschRange4G;
                    gyro.sampleFrequency = sampleFrequency;
                    gyro.fullScaleRange = MBLGyroBMI160Range500;
                    
                    
                    [currdevice.led flashLEDColorAsync:[UIColor blueColor]
                                         withIntensity:1
                                       numberOfFlashes:5];
                    [currdevice.accelerometer.dataReadyEvent startLoggingAsync];
                    [currdevice.gyro.dataReadyEvent startLoggingAsync];
                    
                    NSLog(@"Device %@ start logging? Accel: %d, Gyro: %d",currdevice.name,
                                    [currdevice.accelerometer.dataReadyEvent isLogging],
                                    [currdevice.gyro.dataReadyEvent isLogging]);
                }
            }
            [hud hide:YES afterDelay:1];
            [self disable_button:_startLoggingButton];
            [self enable_button:_stopLoggingButton];
        }];
    }
}


- (IBAction)stopLogRecording:(id)sender {
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            if ([connectedDevices containsObject:device.name]) {
                MBProgressHUD *hud = [self busyIndicator:@"Stopping..."];
                int ix = (int) [connectedDevices indexOfObject:device.name];
                
                //Stop streaming data and store in local data arrays.
                [device.led flashLEDColorAsync:[UIColor redColor]
                                 withIntensity:1
                               numberOfFlashes:5];
                [[[device.accelerometer.dataReadyEvent downloadLogAndStopLoggingAsync:YES
                                                                     progressHandler:^(float number) {
                    // Update progress bar, as this can take upwards of one minute to download a full log
                    [self.downloadProgressAccel setText:[NSString stringWithFormat:@"%f",number*100]];
                }] success:^(NSArray<MBLNumericData *> * _Nonnull result) {
                    NSString *strData;
                    NSArray *entries;
                    
                    // array contains all the log entries
                    for (MBLNumericData *entry in result) {
                        strData = [NSString stringWithFormat:@"%@",entry];
                        entries = [strData componentsSeparatedByString:@","];
                        
                        [self.accelerometerDataArrays[ix] addObject:
                                    @[entry.timestamp,
                                      @([entries[0] floatValue]),
                                      @([entries[1] floatValue]),
                                      @([entries[2] floatValue])]];
                    }
                    NSLog(@"Accel %@ returns %lu data points.",device.name,[result count]);
                    NSLog(@"Device %@ still logging? Accel: %d, Gyro: %d",device.name,
                                        [device.accelerometer.dataReadyEvent isLogging],
                                        [device.gyro.dataReadyEvent isLogging]);
                }] failure:^(NSError* error) {
                    NSLog(@"Failed to get accelerometer data!");
                }];
                
                [[[device.gyro.dataReadyEvent downloadLogAndStopLoggingAsync:YES
                                                            progressHandler:^(float number) {
                    // Update progress bar using.
                    [self.downloadProgressGyro setText:[NSString stringWithFormat:@"%f",number*100]];
                }] success:^(NSArray<MBLNumericData *> * _Nonnull result) {
                    NSString *strData;
                    NSArray *entries;
                    
                    // array contains all the log entries
                    for (MBLNumericData *entry in result) {
                        strData = [NSString stringWithFormat:@"%@",entry];
                        entries = [strData componentsSeparatedByString:@","];
                        
                        [self.gyroDataArrays[ix] addObject:
                                     @[entry.timestamp,
                                       @([entries[0] floatValue]),
                                       @([entries[1] floatValue]),
                                       @([entries[2] floatValue])]];
                    }
                    NSLog(@"Gyro %@ returns %lu data points.",device.name,[result count]);
                    [hud hide:YES];
                }] failure:^(NSError* error) {
                    NSLog(@"Failed to get gyrometer data!");
                    [hud hide:YES];
                }];
                
                NSLog(@"Stopping record %d",ix);
            }
        }
        [self disable_button:_stopLoggingButton];
        [self enable_button:_resetLoggingButton];
    }];
}


- (IBAction)saveFiles:(id)sender {
    unsigned long int gyroCount,accelCount,lessCount,moreCount;
    NSMutableArray *allCounts = [NSMutableArray array];
    MBProgressHUD *hud;
    NSArray *paths;
    NSString *documentsDirectory;
    NSDateFormatter *dateFormatter;
    NSDate *timeNow;
    NSString *strTimeNow;
    NSMutableArray *combinedData = [NSMutableArray array];
    UIAlertController *alert;
    UIAlertAction *closeAction;
    NSString *path;
    NSString *msg;
    
    
    hud = [self busyIndicator:@"Saving..."];
    
    NSLog(@"Writing files...");
    paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    documentsDirectory = [paths objectAtIndex:0];
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    
    // Get current time for unique file names.
    timeNow = [NSDate date];
    strTimeNow = [dateFormatter stringFromDate:timeNow];
    
    for (int i=0; i<[self.accelerometerDataArrays count]; i++) {
        // Combine arrays.
        // Find longer array and save up to length of shorter array because presumably they are
        // measured at the same time points.
        // NOTE: this is not right. must save all recorded time points
        gyroCount = [self.gyroDataArrays[i] count];
        accelCount = [self.accelerometerDataArrays[i] count];
        [allCounts addObject:@(accelCount)];
        [allCounts addObject:@(gyroCount)];
        
        if (gyroCount<accelCount) {
            NSLog(@"Device %@ gyro has less measurements (%lu vs %lu).",
                    connectedDevices[i],gyroCount,accelCount);
            lessCount = gyroCount;
            moreCount = accelCount;
        } else {
            NSLog(@"Device %@ accel has less measurements (%lu vs %lu).",
                    connectedDevices[i],gyroCount,accelCount);
            lessCount = accelCount;
            moreCount = gyroCount;
        }
        // Columns of [timeStamp,x,y,z,timeStamp,x,y,z].
        for (int j=0;j<moreCount;j++ ) {
            if (j<lessCount) {
                [combinedData addObject:@[
                    [dateFormatter stringFromDate:self.accelerometerDataArrays[i][j][0]],
                    self.accelerometerDataArrays[i][j][1],
                    self.accelerometerDataArrays[i][j][2],
                    self.accelerometerDataArrays[i][j][3],
                    [dateFormatter stringFromDate:self.gyroDataArrays[i][j][0]],
                    self.gyroDataArrays[i][j][1],
                    self.gyroDataArrays[i][j][2],
                    self.gyroDataArrays[i][j][3]
                ]];
            } else {
                if (gyroCount<accelCount) {
                    [combinedData addObject:@[
                        [dateFormatter stringFromDate:self.accelerometerDataArrays[i][j][0]],
                        self.accelerometerDataArrays[i][j][1],
                        self.accelerometerDataArrays[i][j][2],
                        self.accelerometerDataArrays[i][j][3],
                        [dateFormatter stringFromDate:self.gyroDataArrays[i][gyroCount-1][0]],
                        @"NaN",@"NaN",@"NaN",
                        ]];
                } else {
                    [combinedData addObject:@[
                        [dateFormatter stringFromDate:self.accelerometerDataArrays[i][accelCount-1][0]],
                        @"NaN",@"NaN",@"NaN",
                        [dateFormatter stringFromDate:self.gyroDataArrays[i][j][0]],
                        self.gyroDataArrays[i][j][1],
                        self.gyroDataArrays[i][j][2],
                        self.gyroDataArrays[i][j][3]
                        ]];
                }
            }
        }
        NSLog(@"Done reading out data arrays.");
        
        // Write data to file.
        path = [documentsDirectory stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@_%@_sample%d.plist",
                 strTimeNow,connectedDevices[i],sampleFrequency]];
        [combinedData writeToFile:path atomically:YES];
        if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {
            NSLog(@"%@ writable\n",path);
        }else {
            NSLog(@"%@ not writable\n",path);
        }
    }
    [hud hide:YES afterDelay:0.5];
    
    // Show datetime prefix in alert box.
    msg = [NSString stringWithFormat:@"With prefix %@\n",strTimeNow];
    for (int i=0; i<[allCounts count]; i++) {
        msg = [msg stringByAppendingString:[NSString stringWithFormat:@"%@, ",allCounts[i]]];
    }
    alert = [UIAlertController alertControllerWithTitle:@"Saved files"
                                                message:msg
                                         preferredStyle:UIAlertControllerStyleAlert];
    closeAction = [UIAlertAction actionWithTitle:@"Close"
                                           style:UIAlertActionStyleDefault
                                         handler:nil];
    [alert addAction:closeAction];
    [self presentViewController:alert animated:NO completion:nil];
    
    NSLog(@"Done writing.");
}


- (IBAction)disconnectDevices:(id)sender {
    MBProgressHUD *hud = [self busyIndicator:@"Disconnecting..."];
    [connectedDevices removeAllObjects];
    
    //Disconnect.
    [[manager retrieveSavedMetaWearsAsync] success:^(NSArray *listOfDevices) {
        for (MBLMetaWear *device in listOfDevices) {
            if ([connectedDevices containsObject:device.name]) {
                [device disconnectWithHandler:^(NSError* error) {
                    if (error) {
                        NSLog(@"Problems disconnecting.");
                    }
                    else {
                        NSLog(@"Disconnected from %@",device.name);
                        //Reduce transmit power back to default.
                        device.settings.transmitPower = MBLTransmitPower0dBm;
                    }
                }];
            // Erase all devices from memory.
            [device forgetDevice];
            };
        };
        [self updateLabel:@"" :connectedDevicesLabel];
    }];
    
    pickerData = @[@"No devices."];
    [devicePicker reloadAllComponents];
    [self disable_button:_flashRed];
    [self clearTable];
    [hud hide:YES afterDelay:0.5];
}


- (IBAction)clearFilesButton:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Please confirm."
                                  message:@"Delete all files?"
                                  preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:
                                 UIAlertActionStyleDefault handler:nil];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes"
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *action) {
                                           [self clearDocumentsFolder];
                                       }];
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:NO completion:nil];
}


- (IBAction)exitProgram:(id)sender {
    //Disconnect devices before exiting.
    [self yes_no_alert_title:@"Confirm exit"
                     message:@"Really exit?"
                     handler:^(UIAlertAction *action){
                         [self disconnectDevices:self];
                         exit(0);
                         }];
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

- (void) initialize_info_arrays {
    self.deviceIdentifiers = [NSMutableArray array];
    self.deviceInformation = [NSMutableArray array];
    connectedDevices = [NSMutableArray array];
}

- (void) initialize_data_arrays {
    self.accelerometerDataArrays = [NSMutableArray array];  // Arrays containing logs for each device.
    self.gyroDataArrays = [NSMutableArray array];  // Arrays containing logs for each device.
    
    for (int i=0;i<[connectedDevices count];i++) {
        //Initialize arrays for collecting data.
        self.accelerometerDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
        self.gyroDataArrays[i] = [[NSMutableArray alloc] initWithCapacity:INITIAL_CAPACITY];
    }
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

- (void)popup_title:(NSString*)title message:(NSString*)msg {
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:title
                                message:msg
                                preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close" style:
                                  UIAlertActionStyleDefault handler:nil];
    [alert addAction:closeAction];
    [self presentViewController:alert animated:NO completion:nil];
}


- (void)yes_no_alert_title:(NSString*)title
                   message:(NSString*)msg
                   handler:(void (^)(UIAlertAction*))action {
    // Show yes or no dialog pop up.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                           message:msg
                                                    preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No" style:
                               UIAlertActionStyleDefault handler:nil];
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Yes"
                                                        style:UIAlertActionStyleDefault
                                                      handler:action];
    [alert addAction:yesAction];
    [alert addAction:noAction];
    [self presentViewController:alert animated:NO completion:nil];
}

- (bool)checkForConnectedDevices {
    if ([connectedDevices count]==0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No connected devices."
                                     message:@"Must connect some devices first."
                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close"
                                        style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:closeAction];
        [self presentViewController:alert animated:NO completion:nil];
        return NO;
    } else {
        return YES;
    }
}

- (void)clearTable {
    for (NSIndexPath *i in [_selectDevicesTable indexPathsForSelectedRows]) {
        [_selectDevicesTable deselectRowAtIndexPath:i animated:NO];
    }
}

- (NSMutableArray*)get_ids:(NSArray*)listOfDevices {
    NSMutableArray *thisids = [NSMutableArray array];
    for (MBLMetaWear *l in listOfDevices) {
        [thisids addObject: l.name];
    }
    return thisids;
}

- (void)clearDocumentsFolder {
    NSFileManager  *manager = [NSFileManager defaultManager];
    
    // the preferred way to get the apps documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    // grab all the files in the documents dir
    NSArray *allFiles = [manager contentsOfDirectoryAtPath:documentsDirectory error:nil];
    
    // filter the array for only sqlite files
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH '.plist'"];
    NSArray *plistFiles = [allFiles filteredArrayUsingPredicate:fltr];
    
    // use fast enumeration to iterate the array and delete the files
    for (NSString *plistFile in plistFiles)
    {
        NSError *error = nil;
        [manager removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:plistFile] error:&error];
        NSAssert(!error, @"Assertion: plistFile file deletion shall never throw an error.");
    }}

- (void)disable_button:(UIButton*) button {
    [button setUserInteractionEnabled:NO];
    [button setBackgroundColor:[UIColor grayColor]];
}

- (void)enable_button:(UIButton*) button{
    [button setUserInteractionEnabled:YES];
    [button setBackgroundColor:[UIColor whiteColor]];
}

- (void)logCleanup:(MBLMetaWear*)device handler:(MBLErrorHandler)handler
{
    // In order for the device to actaully erase the flash memory we can't be in a connection
    // so temporally disconnect to allow flash to erase.
    [device disconnectWithHandler:^(NSError *error) {
        if (error) {
            if (handler) {
                handler(error);
            }
        } else {
            [device connectWithTimeout:20 handler:^(NSError *error) {
                if (handler) {
                    handler(error);
                }
            }];
        }
    }];
}


@end