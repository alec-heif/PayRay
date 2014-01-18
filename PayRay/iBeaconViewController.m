//
//  iBeaconViewController.m
//  PayRay
//
//  Created by aheifetz on 1/18/14.
//  Copyright (c) 2014 Kathryn Siegel. All rights reserved.
//

#import "iBeaconViewController.h"
#import "ViewController.h"
#import "LocationModel.h"
#import <Firebase/Firebase.h>

@interface iBeaconViewController ()

@end

@implementation iBeaconViewController {
    NSMutableDictionary *_beacons;
    CLLocationManager *_locationManager;
    CLBeaconRegion *_region;
    BOOL _inProgress;
    NSMutableArray *_rangedBeacons;
    BOOL _master;
    BOOL _slave;
    NSString* _uuid;
    NSString* _userId;
    Firebase* _baseRef;
    int _table;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _beacons = [[NSMutableDictionary alloc] init];
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _inProgress = NO;
        _uuid = @"7AAF1FFA-7EA5-44A5-B4E8-0A8BBDF0B775";
        _baseRef = [[Firebase alloc] initWithUrl:@"https://pay-ray.firebaseIO-demo.com"];
    }
    return self;
}

-(void)createTable
{
    _master = true;
    [self startRangingForBeacons];
}

- (void)createBeaconRegion
{
    if (_region)
        return;
    NSString* identifier = @"PayRay";
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:_uuid];
    _region = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID identifier:identifier];
}

- (void)turnOnRanging
{
    NSLog(@"Turning on ranging...");
    
    if (_locationManager.rangedRegions.count > 0) {
        NSLog(@"Didn't turn on ranging: Ranging already on.");
        return;
    }
    
    [self createBeaconRegion];
    [_locationManager startRangingBeaconsInRegion:_region];
    
    NSLog(@"Ranging turned on for region: %@.", _region);
}

- (void)startRangingForBeacons
{
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    _beacons = [[NSMutableDictionary alloc] init];
    
    [self turnOnRanging];
}

- (void)stopRangingForBeacons
{
    if (_locationManager.rangedRegions.count == 0) {
        NSLog(@"Didn't turn off ranging: Ranging already off.");
        return;
    }
    
    [_locationManager stopRangingBeaconsInRegion:_region];
    
    NSLog(@"Turned off ranging.");
}

-(NSMutableArray*)addUsers:(NSArray*)beacons toTable:(int)tableId
{
    NSMutableArray* users = [[NSMutableArray alloc] init];
    for (CLBeacon *beacon in beacons) {
        int majorValue = beacon.major.integerValue;
        int minorValue = beacon.minor.integerValue;
        NSString* beaconUserId = [NSString stringWithFormat:@"%04i%04i",majorValue, minorValue];
        [users addObject:beaconUserId];
        Firebase* tableUsersRef = [_baseRef childByAppendingPath:[NSString stringWithFormat:@"TABLES/%i/table_users/%@", tableId, beaconUserId]];
        [tableUsersRef setValue:@{}];
    }
    return users;
}

-(void)addTable:(int)tableId toUsers:(NSMutableArray*)users
{
    for (NSString* user in users) {
        Firebase* tableUsersRef = [_baseRef childByAppendingPath:[NSString stringWithFormat:@"USERS/%@", user]];
        [tableUsersRef updateChildValues:@{@"table": [NSNumber numberWithInt: tableId]}];
    }
}



- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray*)beacons inRegion:(CLBeaconRegion *)region
{
    if (beacons.count == 0) {
        NSLog(@"No beacons found nearby.");
    } else {
        NSLog(@"Found %lu %@.", (unsigned long)[beacons count],
              [beacons count] > 1 ? @"beacons" : @"beacon");
    }
    if(_master) {
        //We are the master: add everyone else in range to the table only once
        _master = false;
        //Add a table to TABLES
        Firebase* tablesRef = [_baseRef childByAppendingPath:@"TABLES"];
        [tablesRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            int newId = snapshot.childrenCount;
            
            //First, add yourself to the table
            NSString* newIdString = [NSString stringWithFormat:@"%i/table_users/%@",newId, _userId];
            [[tablesRef childByAppendingPath:newIdString] setValue:@{}];
            
            //Next, add all users to this table
            NSMutableArray* users = [self addUsers:beacons toTable:newId];
            
            //Then, add yourself to the new list of user ids
            [users addObject:_userId];
            
            //Finally, add the table to all users (including yourself). This will trigger a change event, which will set _slave = true
            [self addTable:newId toUsers:users];
        }];
    }
    else if(_slave) {
        //We are a slave: get the distance to all other users and upload it to Firebase so the master can use it
        _slave = false;
        Firebase* tableUsersRef = [_baseRef childByAppendingPath:[NSString stringWithFormat:@"TABLES/%i/table_users/%@", tableId, beaconUserId]];

    }
}

-(void)getDistancesToBeacons: (NSArray*)beacons {
    
}

-(double)getDistanceToBeacon: (CLBeacon*)beacon {
    double accuracy = beacon.accuracy;
    return accuracy;
    
}



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
