//
//  ReadBarcodeViewController.h
//  SmartTagApp
//

#import <UIKit/UIKit.h>

@interface BarcodeReaderViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *scannedDataLabel;
- (IBAction) backButtonClicked:(id) sender;

@end
