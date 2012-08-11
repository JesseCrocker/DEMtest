//
//  demReverseGeocoder.h
//  DEM viewer
//
//  Created by Jesse Crocker on 8/8/12.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#define coordinateOutsideOfRange -10000

@interface demReverseGeocoder : NSObject
@property (nonatomic, strong) NSString *baseFileName;
@property (assign) int noDataValue;

+(demReverseGeocoder *)newCoderWithFileBaseName:(NSString *)filename;
-(void)loadFile:(NSString *)filename;
-(float)elevationForCoordinate:(CLLocationCoordinate2D)coordinate;
-(BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate;
-(MKCoordinateRegion)region;

@end
