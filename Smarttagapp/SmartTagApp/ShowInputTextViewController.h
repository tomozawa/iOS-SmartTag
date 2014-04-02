//
//  ShowInputTextViewController.h
//  SmartTagApp
//

#import <UIKit/UIKit.h>
@protocol ShowInputTextDelegate
-(void)setShowInputText:(NSString *)text;
@end


@interface ShowInputTextViewController : UIViewController

@property (nonatomic,assign) id<ShowInputTextDelegate> delegate;
@property (nonatomic,copy) NSString *messageText;
@property (weak, nonatomic) IBOutlet UITextView *messageTextField;

@end
