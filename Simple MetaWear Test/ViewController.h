//
//  ViewController.h
//  Simple MetaWear Test
//
//  Created by Eddie on 2/25/16.
//  Copyright © 2016 Eddie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MetaWear/MetaWear.h>

@interface ViewController : UIViewController
@property (strong, nonatomic) NSMutableArray *accelerometerDataArrays;
@property NSString *path;
@property (weak, nonatomic) IBOutlet UILabel *listOfFoundMetaWears;
@property (weak, nonatomic) IBOutlet UILabel *connectedDevicesLabel;

@property MBLMetaWearManager *manager;

- (IBAction)startSearch:(id)sender; 
- (IBAction)startRecording:(id)sender;
- (void)updateLabel : (NSMutableString*)text : (UILabel*)label;

@end

