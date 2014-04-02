//
//  ShowInputTextViewController.m
//  SmartTagApp
//

#import "ShowInputTextViewController.h"
#import "Adapter.h"

@interface ShowInputTextViewController ()

@end

@implementation ShowInputTextViewController
@synthesize delegate = _delegate;

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    UIView* accessoryView =[[UIView alloc] initWithFrame:CGRectMake(0,0,320,40)];
    accessoryView.backgroundColor = [UIColor clearColor];
    
    // ボタンを作成する。
    UIButton* closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(220,0,100,40);
    [closeButton setImage:[UIImage imageNamed:@"close_btn.png"] forState:UIControlStateNormal];
    // ボタンを押したときによばれる動作を設定する。
    [closeButton addTarget:self action:@selector(closeKeyboard:) forControlEvents:UIControlEventTouchUpInside];
    // ボタンをViewに貼る
    [accessoryView addSubview:closeButton];
    
    
    
    _messageTextField.text = _messageText;
    
    _messageTextField.inputAccessoryView = accessoryView;
    [_messageTextField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)closeKeyboard:(id)sender
{
    [_messageTextField resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:^{
        [_delegate setShowInputText:_messageTextField.text];
    }];
}


@end
