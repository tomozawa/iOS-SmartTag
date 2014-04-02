//
//  ReadBarcodeViewController.m
//  SmartTagApp
//

#import "BarcodeReaderViewController.h"
#import "Adapter.h"

@interface BarcodeReaderViewController ()

@end

@implementation BarcodeReaderViewController




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

- (IBAction) backButtonClicked:(id) sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    
    //バーコード読み取り開始
    [Adapter addObserver:self selector:@selector(recieveData:) name:ADAPTER_EVENT_BARCODE_DATA_RECIEVED];
}

- (void)recieveData:(NSNotification *)notification
{
    NSString *data = [[notification userInfo] objectForKey:@"DATA"];
    NSLog(@"Recieve Scanned Data from Barcode Reader : %@", data);
    _scannedDataLabel.text = data;
}

- (void)viewDidDisappear:(BOOL)animated
{
    //バーコード読み取り停止
    [Adapter removeObserver:self name:ADAPTER_EVENT_BARCODE_DATA_RECIEVED];
    
    [super viewDidDisappear:animated];
}

@end
