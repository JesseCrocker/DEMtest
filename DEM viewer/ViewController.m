//
//  ViewController.m
//  DEM viewer
//
//  Created by Jesse Crocker on 8/8/12.
//

#import "ViewController.h"
#import "demReverseGeocoder.h"
#import "AFNetworking.h" //for google elevation api requests
#import "DDXML.h" //for parseing response from google elvation
#import "NSArray+JCaddons.h"

#import "RMMapContents.h"
#import "RMFoundation.h"

@interface ViewController (){
    demReverseGeocoder *dem;
    float webElevation;
    float demElevation;
}

@end

@implementation ViewController
@synthesize demElevationLabel;
@synthesize webElevationLabel;
@synthesize differenceLabel;
@synthesize mapView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self loadDEM];
    [RMMapView class];
    mapView.delegate = self;
    NSString *zipPath = [[NSBundle mainBundle] pathForResource:@"36069441" ofType:@"zip"];
    if([self unpackDownload:zipPath]){
        
    }
}

- (void)viewDidUnload
{
    [self setDemElevationLabel:nil];
    [self setWebElevationLabel:nil];
    [self setMapView:nil];
    [self setDifferenceLabel:nil];
    [super viewDidUnload];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}


#pragma mark - 
-(bool)unpackDownload:(NSString *)pathToZip{
    NSString *destinationPath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:@"DEM"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:destinationPath]){
        NSError *error;
        if(![fileManager createDirectoryAtPath:destinationPath
                   withIntermediateDirectories:NO
                                    attributes:nil
                                         error:&error]){
            NSLog(@"Error creating directory: %@", error.debugDescription);
        }
    }
    
    NSArray *filesBeforeUnzipping = [fileManager contentsOfDirectoryAtPath:destinationPath
                                                                     error:nil];
    if([SSZipArchive unzipFileAtPath:pathToZip toDestination:destinationPath]){
        NSMutableArray *newFiles = [NSMutableArray array];
        for(NSString *file in [fileManager contentsOfDirectoryAtPath:destinationPath
                                                               error:nil]){
            if([filesBeforeUnzipping indexOfString:file] == -1){
                [newFiles addObject:file];
            }
        }
//NSAssert(newFiles.count == 1, @"Expected 1 new file, found %i", newFiles.count);
        if(newFiles.count == 1){
            NSString *newDirectory = [destinationPath stringByAppendingPathComponent:[newFiles objectAtIndex:0]];
            NSArray *newDirectoryContents;
            newDirectoryContents = [fileManager contentsOfDirectoryAtPath:newDirectory
                                                                    error:nil];
            NSString *demFileBaseName;
            NSString *filePath;
            for(NSString *file in newDirectoryContents){
                filePath = [newDirectory stringByAppendingPathComponent:file];
                NSString *extension = file.pathExtension;
                if(([extension isEqualToString:@"flt"] || [extension isEqualToString:@"hdr"]) ){
                    demFileBaseName = [filePath stringByDeletingPathExtension];
                }else{
                    //delete all of the other files included in the zip
                    NSError *error;
                    if(![fileManager removeItemAtPath:filePath error:&error]){
                        NSLog(@"Error deleteing file:%@", error.debugDescription);
                    }
                }
            }
            NSLog(@"found dem file base name: %@", demFileBaseName);
            [self loadDEM:demFileBaseName];
        }else{//could not find new directory
            return NO;
        }
        return YES;
    }else{
        NSLog(@"failed unzipping");
        return NO;
    }
}

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


-(void)loadDEM:(NSString *)path{
    //expects a path without extension
    dem = [demReverseGeocoder newCoderWithFileBaseName:path];
    [[mapView contents] zoomWithLatLngBoundsNorthEast:CLLocationCoordinate2DMake(dem.region.center.latitude + .5, dem.region.center.longitude + .5)
                                            SouthWest:CLLocationCoordinate2DMake(dem.region.center.latitude - .5, dem.region.center.longitude - .5)];
}

-(void)lookupCoordinate:(CLLocationCoordinate2D)coordinate{
    demElevation = [dem elevationForCoordinate:coordinate];
    [self lookupElevationFromGoogle:coordinate];
    self.demElevationLabel.text = [NSString stringWithFormat:@"%1.3f M", demElevation];
}

#pragma mark - RMMapViewDelegate
- (void) singleTapOnMap: (RMMapView*) map At: (CGPoint) point
{
    CLLocationCoordinate2D tapped = [[mapView contents] pixelToLatLong:point];
    NSLog(@"map tapped %1.5f, %1.5f", tapped.latitude, tapped.longitude);
    if([dem containsCoordinate:tapped]){
        NSLog(@"Looking up elevation");
        [self lookupCoordinate:tapped];
    }else{
        webElevationLabel.text = @"";
        demElevationLabel.text = @"";
        differenceLabel.text = @"";
    }
}

#pragma mark - sszip delegate
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo{
    NSLog(@"did unzip fileindex:%i, total files:%i, archivepath:%@", fileIndex, totalFiles, archivePath);
}


#pragma mark -
-(void)lookupElevationFromGoogle:(CLLocationCoordinate2D)coordinate{
    //For verify accuracy of results from DEM
    NSString *urlString = [NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/elevation/xml?locations=%1.7f,%1.7f&sensor=true",
                           coordinate.latitude, coordinate.longitude];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    AFHTTPRequestOperation *request = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
    [request setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        DDXMLDocument *xmlDoc = [[DDXMLDocument alloc] initWithData:responseObject options:0 error:nil];
        if(xmlDoc != nil){
            DDXMLNode *elevationNode = [[xmlDoc nodesForXPath:@"//elevation" error:nil] lastObject];
            if(elevationNode != nil){
                NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                NSNumber *elevation = [numberFormatter numberFromString:elevationNode.stringValue];
                webElevation = elevation.floatValue;
                self.differenceLabel.text = [NSString stringWithFormat:@"%1.1f M", fabsf(webElevation - demElevation)];
                self.webElevationLabel.text = [NSString stringWithFormat:@"%1.3f M", elevation.floatValue];
            }else{
                self.webElevationLabel.text = @"Error";
            }
        }else{
            self.webElevationLabel.text = @"Error";
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"elevation lookup request failed %@", [error localizedDescription]);
    }];
    [request start];
}

@end
