//
//  demReverseGeocoder.m
//  DEM viewer
//
//  Created by Jesse Crocker on 8/8/12.
// designed to work with USGS NED GridFloat(.flt) files
// tested with 1Arc second files, but should work with 1/3arc
//

#import "demReverseGeocoder.h"

@interface demReverseGeocoder(){
    NSData *elevationData;
    int cols;
    int rows;
    double xLLCorner;
    double yLLCorner;
    double cellSize;
}

@end

@implementation demReverseGeocoder

@synthesize baseFileName;
@synthesize noDataValue;

+(demReverseGeocoder *)newCoderWithFileBaseName:(NSString *)filename{
    demReverseGeocoder *newCoder = [[demReverseGeocoder alloc] init];
    [newCoder loadFile:filename];
    return newCoder;
}

-(void)loadFile:(NSString *)filename{
    self.baseFileName = filename;
    [self loadHeaderFile];
    [self loadData];
    int expectedLength = cols*rows*4;
    NSAssert(expectedLength == elevationData.length, @"Elevation data was not expected length");
}

-(void)loadData{
    elevationData = [NSData dataWithContentsOfFile:[self.baseFileName stringByAppendingPathExtension:@"flt"]];
}

-(void)loadHeaderFile{
    NSNumberFormatter *numberFormatter = [NSNumberFormatter new];
    
    NSError *error;
    NSString *header;
    NSString *filename = [self.baseFileName stringByAppendingPathExtension:@"hdr"];
    if(!(header = [NSString stringWithContentsOfFile:filename
                                            encoding:NSStringEncodingConversionAllowLossy
                                               error:&error])){
        NSLog(@"Error opening file %@: %@", filename, error.debugDescription );
    }
    
    [header enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSRange whitespaceRange = [line  rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(whitespaceRange.location != NSNotFound){
            line = [line stringByReplacingCharactersInRange:whitespaceRange withString:@":"];
            line = [line stringByReplacingOccurrencesOfString:@" " withString:@""];
        }
        NSArray *components = [line componentsSeparatedByString:@":"];
        if(components.count == 2){
            NSNumber *number = [numberFormatter numberFromString:[components objectAtIndex:1]];
            if(number){
                if([[components objectAtIndex:0] isEqualToString:@"ncols"]){
                    cols = number.intValue;
                }else if([[components objectAtIndex:0] isEqualToString:@"nrows"]){
                    rows = number.intValue;
                }else if([[components objectAtIndex:0] isEqualToString:@"xllcorner"]){
                    xLLCorner = number.doubleValue;
                }else if([[components objectAtIndex:0] isEqualToString:@"yllcorner"]){
                    yLLCorner = number.doubleValue;
                }else if([[components objectAtIndex:0] isEqualToString:@"cellsize"]){
                    cellSize = number.doubleValue;
                }else if([[components objectAtIndex:0] isEqualToString:@"NODATA_value"]){
                    noDataValue = number.intValue;
                }
            }
        }else{
            NSLog(@"Irregular number of components in line %@", line);
        }
    }];
}

-(float)elevationForCoordinate:(CLLocationCoordinate2D)coordinate{
    if(![self containsCoordinate:coordinate]){
        return coordinateOutsideOfRange;
    }
    
    if(!elevationData)
        [self loadData];
    
    //file origin is UL corner, row at a time
    float yULcorner = yLLCorner + (cellSize * rows);
    float latitudeDelta = yULcorner - coordinate.latitude;
    float longitudeDelta = coordinate.longitude - xLLCorner;

   // NSLog(@"Latitude delta: %1.5f, longitude delta %1.5f", latitudeDelta, longitudeDelta);
   
    int latitudeCells = latitudeDelta/cellSize;
    int longitudeCells = longitudeDelta/cellSize;
    //NSLog(@"Latitude cells: %i, longitude cells %i", latitudeCells, longitudeCells);


    int totalCells = (latitudeCells * cols) + longitudeCells;
    NSAssert((totalCells * 4 ) + 4 <= elevationData.length, @"Cell position beyond end of file");
    
    uint32_t e = 0;
    [elevationData getBytes:&e range:NSMakeRange(totalCells * 4, 4)];
    uint32_t temp = CFSwapInt32BigToHost(e);
    float converted = *((float*)&temp);
    
    return converted;
}

-(BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate{
    float latitudeDelta = coordinate.latitude - yLLCorner;
    if(latitudeDelta > 1.003333 || latitudeDelta < 0){
        return NO;
    }
    
    float longitudeDelta = coordinate.longitude - xLLCorner;
    if(longitudeDelta > 1.003333 || longitudeDelta < 0){
        return NO;
    }
    
    return YES;
}

-(MKCoordinateRegion)region{
    return MKCoordinateRegionMake(CLLocationCoordinate2DMake(yLLCorner + (0.5 * cellSize * cols), xLLCorner + (0.5 * cellSize * rows)),
                                  MKCoordinateSpanMake(1.0, 1.0));
}

@end
