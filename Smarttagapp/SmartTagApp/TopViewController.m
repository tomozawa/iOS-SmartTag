//
//  TopViewController.m
//  SmartTagApp
//

#import "TopViewController.h"
#import "Port110.h"
#import "Adapter.h"

@interface TopViewController ()

@end

@implementation TopViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [Adapter initializeAdapter];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //Port110と未接続の場合は接続試行
    if(![Port110 isConnected])
    {
        [self findPort110];
    }
}



-(UIViewController *)showModal:(NSString *)modalID
{
    UIViewController *view = [self.storyboard instantiateViewControllerWithIdentifier:modalID];
    [self presentViewController:view animated:YES completion:nil];
    return view;
}




-(void)findPort110
{
    [Adapter addObserver:self selector:@selector(Port110Connected) name:ADAPTER_EVENT_READY];
    [Adapter findPort110];
}

-(void)Port110Connected
{
    [Port110 removeObserver:self];
//    _nameLabel.text = [NSString stringWithFormat:@"Pairing with %@", [[Port110 peripheralName]stringByReplacingOccurrencesOfString:@"PaSoRi" withString:@"scanner"]];
//FIXME: PaSoRiを表示する場合
    _nameLabel.text = [NSString stringWithFormat:@"Pairing with %@", @"PaSoRi"];
    [self showModal:@"smarttagVC"];
}

- (IBAction)clickSmarttagButton:(id)sender
{
    if(![Port110 isConnected])
    {
        [self findPort110];
    }
    else
    {
        //回路をスマートタグ側に接続
        [Adapter setReaderDevice:RFID_READER];
        
        [self showModal:@"smarttagVC"];
    }
}

- (IBAction)clickBarcodeButton:(id)sender
{
//FIXME:バーコードは無視
//    if(![Port110 isConnected])
//    {
//        [self findPort110];
//    }
//    else
//    {
//        //回路をバーコードリーダー側に接続
//        [Adapter setReaderDevice:BARCODE_READER];
//        
//        [self showModal:@"barcodeVC"];
//    }
}

- (IBAction)clickInfoButton:(id)sender
{
    [self showModal:@"infoVC"];
}

@end
