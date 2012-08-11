//
//  ViewController.h
//  DEM viewer
//
//  Created by Jesse Crocker on 8/8/12.
//

#import <UIKit/UIKit.h>
#import "RMMapView.h"
#import "SSZipArchive.h" //for unpacking zip file downloads

@interface ViewController : UIViewController <RMMapViewDelegate, SSZipArchiveDelegate>
@property (strong, nonatomic) IBOutlet UILabel *demElevationLabel;
@property (strong, nonatomic) IBOutlet UILabel *webElevationLabel;
@property (strong, nonatomic) IBOutlet UILabel *differenceLabel;
@property (strong, nonatomic) IBOutlet RMMapView *mapView;

@end
