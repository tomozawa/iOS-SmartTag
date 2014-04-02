//
//  TopViewController.h
//  SmartTagApp
//

#import <UIKit/UIKit.h>

@interface TopViewController : UIViewController

- (IBAction)clickSmarttagButton:(id)sender;
- (IBAction)clickBarcodeButton:(id)sender;
- (IBAction)clickInfoButton:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@end
