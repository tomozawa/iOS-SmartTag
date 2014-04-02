//
//  TopViewController.m
//  SmartTagApp
//

#import <opencv2/opencv.hpp>
#import <CoreImage/CoreImage.h>
#import "SmarttagReaderViewController.h"
#import "BarcodeReaderViewController.h"
#import "ShowInputTextViewController.h"
#import "Adapter.h"
#import "SmarttagData.h"
#import "CellContentWithImageView.h"

@interface SmarttagReaderViewController ()

@end

@implementation SmarttagReaderViewController



//デモ画像が格納されているレイアウト番号
int demoLayout[12] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};

//次に表示するデモ画像のインデックス番号
int demoIndex = 0;

//選択中の機能
int selectedFunction;

//選択中の機能を実行済みかどうか
bool doneFunction;

//撮影画像送信中かどうか
bool doImageFunction;

int saveLayoutIndex;

int showRegisteredLayoutIndex;

UIImage *photoImage;

UIImage *textImage;

NSString *writeURLText;

NSString *readURLText;

NSString *showInputTextString;



- (void)viewDidLoad
{
    [super viewDidLoad];
    dataSource = [[NSArray alloc] initWithObjects:
                  @"デモ画像を表示",
                  @"撮影画像を表示",
                  @"入力文字を表示",
                  @"表示画像を登録",
                  @"登録画像を表示",
                  @"URL書き込み",
                  @"ウェブを開く",
                  @"ディスプレイクリア",
                  nil];
    
    [SmarttagData initializeData];
    
    [self setTagIDm:@"" tagType:TAGTYPE_OTHER];
    
    selectedFunction = SHOW_DEMO_IMAGE;
    doneFunction = NO;
    showRegisteredLayoutIndex = 1;
    saveLayoutIndex = 1;
    writeURLText = @"http://aioismarttag.com/";
    _message.text = MESSAGE_TOUCH_SMARTTAG;
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_menuTable selectRowAtIndexPath:[NSIndexPath indexPathForRow:selectedFunction inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
    
    //タグの接触、解放イベントを監視
    [Adapter addObserver:self selector:@selector(smarttagIsTouched) name:ADAPTER_EVENT_SMARTTAG_IS_TOUCHED];
    [Adapter addObserver:self selector:@selector(smarttagIsReleased) name:ADAPTER_EVENT_SMARTTAG_IS_RELEASED];
    
    //ポーリング＆ステータスチェック
    [Adapter startPolling];
    
    //## 撮影画像転送時、１ブロック転送あたりでviewDidAppearが呼ばれ転送カウンタが停止してしまう。
    //## viewDidAppear後に転送を開始することで、カウンタが正しく表示される。
    if (doImageFunction){
        [self doFunction];
        doImageFunction = NO;
    }
    
}


- (void)viewDidDisappear:(BOOL)animated
{
    [Adapter stopPolling];
    
    //タグの接触、解放イベントの監視を中止
    [Adapter removeObserver:self name:ADAPTER_EVENT_SMARTTAG_IS_TOUCHED];
    [Adapter removeObserver:self name:ADAPTER_EVENT_SMARTTAG_IS_RELEASED];
    
    
    [super viewDidDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}



- (IBAction) backButtonClicked:(id) sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}






//スマートタグが接触したときに呼び出される
- (void)smarttagIsTouched
{
    NSLog(@"SMARTTAG is touched");
    
    _message.text = @"";
    [self setTagIDm:[SmarttagData felicaIDm] tagType:[SmarttagData type]];

    if (!doneFunction) {
        [self doFunction];
    }
}

//スマートタグが離れたときに呼び出される
- (void)smarttagIsReleased
{
    NSLog(@"SMARTTAG is released");
    
    _message.text = MESSAGE_TOUCH_SMARTTAG;
    [self setTagIDm:[SmarttagData felicaIDm] tagType:[SmarttagData type]];
    //doneFunction = NO;
}




//機能実行
-(void)doFunction
{
    //カードがタッチされていない場合は実行しない
    if([[SmarttagData felicaIDm] isEqualToString:@""])
    {
        [Adapter startPolling];
        return;
    }
    
    //ポーリング停止
    [Adapter stopPolling];
    
    NSLog(@"******************************");
    NSLog(@"[START] function No.%d(%@)", selectedFunction, [dataSource objectAtIndex:selectedFunction]);
    NSLog(@"******************************");
    
    
    
    _message.text = MESSAGE_CONNECTING;
    
    switch (selectedFunction)
    {
        case SHOW_DEMO_IMAGE: //デモ画像を表示
            [self showDemoImage:demoIndex];
            break;
            
        case SHOW_PHOTO: //撮影画像を表示
            [self showImage:photoImage];
            break;
            
        case SHOW_INPUT_TEXT: //入力文字を表示
            [self showImage:textImage];
            break;
        
        case SAVE_LAYOUT: //表示画像登録
            [self saveLayout:saveLayoutIndex];
            break;
            
        case SHOW_LAYOUT: //登録画像を表示
            [self showRegisteredImage:showRegisteredLayoutIndex];
            break;
            
        case WRITE_URL: //URL書き込み
            [self writeURL:writeURLText];
            break;
            
        case READ_URL: //ウェブを開く
            [self openResisteredWebPage];
            break;
            
        case CLEAR_DISPLAY: //ディスプレイクリア
            [self clearDisplay];
            break;
            
        default:
            break;
    }
}

//function完了時
-(void)functionComplete
{
    [SVProgressHUD showSuccessWithStatus:@"完了しました"];
    NSLog(@"******************************");
    NSLog(@"[COMPLETE] function No.%d(%@)", selectedFunction, [dataSource objectAtIndex:selectedFunction]);
    NSLog(@"******************************");
    _message.text = MESSAGE_COMPLETE;
    doneFunction = YES;
    [Adapter startPolling];
}
//functionエラー終了時
-(void)functionError:(NSString *)errorText
{
    //キャンセル時
    if([errorText isEqualToString:@""])
    {
        [SVProgressHUD showErrorWithStatus:@"キャンセルしました"];
        NSLog(@"******************************");
        NSLog(@"[CANCEL] function No.%d(%@)", selectedFunction, [dataSource objectAtIndex:selectedFunction]);
        NSLog(@"******************************");
        _message.text = MESSAGE_CANCEL;
        [Adapter startPolling];
    }
    else
    {
        [SVProgressHUD showErrorWithStatus:@"エラーが発生しました"];
        NSLog(@"******************************");
        NSLog(@"[ERROR] function No.%d(%@)", selectedFunction, [dataSource objectAtIndex:selectedFunction]);
        NSLog(@"******************************");
        [SmarttagData initializeData];
        _message.text = MESSAGE_ERROR;
        [self showErrorAlert:errorText];
    }
}




//スマートタグのIDmと、タグ画像の表示
- (void)setTagIDm:(NSString *)idm tagType:(SmartTagType)type
{
    //画像の表示
    switch(type)
    {
        case TAGTYPE_20_INCH:
            _smartTagImage20.hidden = NO;
            _smartTagImage27.hidden = YES;
            break;
            
        case TAGTYPE_27_INCH:
            _smartTagImage20.hidden = YES;
            _smartTagImage27.hidden = NO;
            break;
            
        case TAGTYPE_OTHER:
            _smartTagImage20.hidden = YES;
            _smartTagImage27.hidden = YES;
            idm = @"-";
            break;
    }
    
    //IDmの表示
    _tagID.text = [@"ID : " stringByAppendingString:idm];
}







//メニューのTableView周りの設定
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [dataSource count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 66;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //再利用のための名前
    NSString *cellIdentifier = (indexPath.row == SHOW_PHOTO || indexPath.row == SHOW_INPUT_TEXT)? @"CellWithImage" : @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableHeaderFooterViewWithIdentifier:cellIdentifier];
    
    
    UITableViewCellStyle style = UITableViewCellStyleDefault;
    if (indexPath.row == SHOW_DEMO_IMAGE || indexPath.row == SAVE_LAYOUT || indexPath.row == SHOW_LAYOUT)
    {
        style = UITableViewCellStyleValue1;
    }
    else if(indexPath.row == WRITE_URL)
    {
        style = UITableViewCellStyleSubtitle;
    }
    
    if(cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier];
        
        if(indexPath.row == SHOW_PHOTO || indexPath.row == SHOW_INPUT_TEXT)
        {
            //画像プレビュー用のサブビューを乗っける
            CellContentWithImageView *contentView = [CellContentWithImageView cellContentView];
            [cell.contentView addSubview:contentView];
        }
    }
    
    if(indexPath.row == SHOW_PHOTO || indexPath.row == SHOW_INPUT_TEXT)
    {
        //プレビュー画像
        CellContentWithImageView *contentView = [[cell.contentView subviews] objectAtIndex:0];
        UIImage *image = (indexPath.row == SHOW_PHOTO)? photoImage : textImage;
        contentView.image = image;
    }
    
    //ラベルの設定
    cell.textLabel.font = [UIFont boldSystemFontOfSize:20.f];
    cell.textLabel.text = [dataSource objectAtIndex:indexPath.row];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    
    //サブテキストの設定
    if (indexPath.row == SHOW_DEMO_IMAGE)
    {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", demoIndex+1];
        //cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", demoLayout[demoIndex]];
    }
    if (indexPath.row == SAVE_LAYOUT)
    {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", saveLayoutIndex];
    }
    else if (indexPath.row == SHOW_LAYOUT)
    {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", showRegisteredLayoutIndex];
    }
    else if(indexPath.row == WRITE_URL)
    {
        cell.detailTextLabel.text = writeURLText;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    selectedFunction = indexPath.row;
    NSLog(@"****************************");
    NSLog(@"Change Function");
    NSLog(@"function No.%d", selectedFunction);
    NSLog(@"****************************");
    
    [Adapter stopPolling];
    
    doneFunction = NO;
    switch (selectedFunction)
    {
        /*
        case SHOW_DEMO_IMAGE: //デモ画像を表示
            [self setDemoIndex];
            break;
        */    
        case SHOW_PHOTO: //撮影画像を表示
            [self setPhotoImage];
            break;
            
        case SHOW_INPUT_TEXT: //入力文字を表示
        {
            ShowInputTextViewController *showInputTextVC = (ShowInputTextViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"showInputTextVC"];

            showInputTextVC.delegate = self;
            showInputTextVC.messageText = showInputTextString;
            [self presentViewController:showInputTextVC animated:YES completion:nil];
            break;
        }
            
        case SHOW_LAYOUT: //表示画像登録
            [self setShowRegisteredLayoutIndex];
            break;
            
        case SAVE_LAYOUT: //登録画像を表示
            [self setSaveLayoutIndex];
            break;
            
        case WRITE_URL: //URLを登録
            [self setWriteURL];
            break;
            
        default:
            [self doFunction];
            break;
    }
}










//デモ画像の表示
- (void)showDemoImage:(int)index
{
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(showDemoImageComplete) name:ADAPTER_EVENT_SHOW_DEMO_COMPLETE];
    [Adapter addObserver:self selector:@selector(showDemoImageError:) name:ADAPTER_EVENT_ERROR];
    
    //[Adapter showImage:[UIImage imageNamed:[NSString stringWithFormat:@"a%d.png", index]]];
    [Adapter showDemo:demoLayout[index]];
}
//エラー
-(void)showDemoImageError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SHOW_DEMO_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}
//完了
- (void)showDemoImageComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SHOW_DEMO_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
    
    //    demoIndex = (demoIndex+1) % 4; //0~3でループ
    demoIndex = (demoIndex+ 1 )% 12 ; //1~12でループ
    if(12<demoIndex)
    {
        demoIndex = 0 ;
    }
    
    UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:SHOW_DEMO_IMAGE inSection:0]];
    //cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", demoIndex];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", demoIndex+1];
}













//スマートタグのディスプレイをクリア
- (void)clearDisplay
{
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(clearDisplayComplete) name:ADAPTER_EVENT_CLEAR_DISPLAY_COMPLETE];
    [Adapter addObserver:self selector:@selector(clearDisplayError:) name:ADAPTER_EVENT_ERROR];
    [Adapter clearDisplay];
}
//エラー
-(void)clearDisplayError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_CLEAR_DISPLAY_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}
//完了
- (void)clearDisplayComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_CLEAR_DISPLAY_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
}





//デモ画像番号を設定
-(void)setDemoIndex
{
    [self setActionSheetWithDefaultValue:demoIndex-1 tag:SHOW_DEMO_IMAGE];
}
//登録画像表示のlayout番号を設定
-(void)setShowRegisteredLayoutIndex
{
    [self setActionSheetWithDefaultValue:showRegisteredLayoutIndex-1 tag:SHOW_LAYOUT];
}
//表示画像登録のlayout番号を設定
-(void)setSaveLayoutIndex
{
    [self setActionSheetWithDefaultValue:saveLayoutIndex-1 tag:SAVE_LAYOUT];
}
//layout番号の設定Actionsheet表示
-(void)setActionSheetWithDefaultValue:(int)value tag:(int)tag
{
    actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                              delegate:self
                                     cancelButtonTitle:nil
                                destructiveButtonTitle:nil
                                     otherButtonTitles:nil];
    
    [actionSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
    actionSheet.tag = tag;
    //NSLog(@"Set ActionSheet Tag : %d", actionSheet.tag);
    
	UIToolbar *toolBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	toolBar.barStyle = UIBarStyleBlackOpaque;
	[toolBar sizeToFit];
    
	// ピッカーの作成
	UIPickerView *pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 44, 0, 0)];
	pickerView.delegate = self;
	pickerView.showsSelectionIndicator = YES;
    
	// フレキシブルスペースの作成
	UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:self
                                                                            action:nil];
    
	// Doneボタンの作成
	UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                          target:self
                                                                          action:@selector(doneDidPush)];
	
	NSArray *items = [NSArray arrayWithObjects:spacer, done, nil];
	[toolBar setItems:items animated:YES];
	
	// アクションシートへの埋め込みと表示
	[actionSheet addSubview:toolBar];
	[actionSheet addSubview:pickerView];
	[actionSheet showInView:self.view];
    [pickerView selectRow:value inComponent:0 animated:YES];
	[actionSheet setBounds:CGRectMake(0, 0, 320, 464)];
}
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView*)pickerView
{
    return 1;
}

-(NSInteger)pickerView:(UIPickerView*)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return 12;
}

-(NSString*)pickerView:(UIPickerView*)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [NSString stringWithFormat:@"%d", row+1];
}
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    int value = [pickerView selectedRowInComponent:0];
    
    if(actionSheet.tag == SHOW_DEMO_IMAGE)
    {
        demoIndex = value + 1;
    }
    if(actionSheet.tag == SHOW_LAYOUT)
    {
        showRegisteredLayoutIndex = value + 1;
    }
    else if(actionSheet.tag == SAVE_LAYOUT)
    {
        saveLayoutIndex = value + 1;
    }
    
    UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:actionSheet.tag inSection:0]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", value+1];
}
- (void)doneDidPush
{
	[actionSheet dismissWithClickedButtonIndex:0 animated:YES];
    [self doFunction];
}




//スマートタグに登録されている画像を表示する(layout:1-12)
- (void)showRegisteredImage:(int)layout
{
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(showRegisteredImageComplete) name:ADAPTER_EVENT_SHOW_LAYOUT_COMPLETE];
    [Adapter addObserver:self selector:@selector(showRegisteredImageError:) name:ADAPTER_EVENT_ERROR];
    [Adapter showLayout:layout];
}

//エラー
-(void)showRegisteredImageError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SHOW_LAYOUT_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}

//完了
- (void)showRegisteredImageComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SHOW_LAYOUT_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
    
    //表示完了後、自動的にインデックス番号を増やす　1~12でループ
    showRegisteredLayoutIndex = (showRegisteredLayoutIndex % 12) + 1;
    UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:SHOW_LAYOUT inSection:0]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", showRegisteredLayoutIndex];
}





//スマートタグに表示されている画像を登録する(layout:1-12)
- (void)saveLayout:(int)layout
{
    NSLog(@"Save layout:%d", layout);
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(saveLayoutComplete) name:ADAPTER_EVENT_SAVE_LAYOUT_COMPLETE];
    [Adapter addObserver:self selector:@selector(saveLayoutError:) name:ADAPTER_EVENT_ERROR];
    [Adapter saveScreen:layout];
}

//エラー
-(void)saveLayoutError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SAVE_LAYOUT_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}

//完了
- (void)saveLayoutComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SAVE_LAYOUT_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
}







//入力文字表示用の文字を設定
-(void)setShowInputText:(NSString *)text
{
    showInputTextString = text;

    if([SmarttagData type] == TAGTYPE_27_INCH){
        textImage = [self resizeImage:[self imageWithText:text fontSize:16 rectSize:CGSizeMake(264, 176)] width:264 height:176];
    }else {
        textImage = [self resizeImage:[self imageWithText:text fontSize:16 rectSize:CGSizeMake(200, 96)] width:200 height:96];
    }
    
    UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:SHOW_INPUT_TEXT inSection:0]];
    CellContentWithImageView *contentView = [[cell.contentView subviews] objectAtIndex:0];
    contentView.image = [self resizeImage:textImage width:100 height:48];
    
    [self doFunction];
}
- (UIImage *)imageWithText:(NSString *)text fontSize:(CGFloat)fontSize rectSize:(CGSize)rectSize {
    
    // 描画する文字列のフォントを設定。
    UIFont *font = [UIFont systemFontOfSize:fontSize];
    
    // オフスクリーン描画のためのグラフィックスコンテキストを作る。
    if (UIGraphicsBeginImageContextWithOptions != NULL)
        UIGraphicsBeginImageContextWithOptions(rectSize, YES, 0.0f);
    else
        UIGraphicsBeginImageContext(rectSize);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);

    if([SmarttagData type] == TAGTYPE_27_INCH){
    CGContextFillRect(context, CGRectMake(0, 0, 264, 176));
    }else{
        CGContextFillRect(context, CGRectMake(0, 0, 200, 96));
    }
    
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    // 文字列の描画領域のサイズをあらかじめ算出しておく。
    CGSize textAreaSize = [text sizeWithFont:font constrainedToSize:rectSize];
    
    // 描画対象領域の中央に文字列を描画する。
    [text drawInRect:CGRectMake((rectSize.width - textAreaSize.width) * 0.5f,
                                (rectSize.height - textAreaSize.height) * 0.5f,
                                textAreaSize.width,
                                textAreaSize.height)
            withFont:font
       lineBreakMode:NSLineBreakByWordWrapping
           alignment:NSTextAlignmentLeft];
    
    // コンテキストから画像オブジェクトを作成する。
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return image;
}





//画像撮影
- (void)setPhotoImage
{
    //撮影コントローラー表示
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        NSString *coverType = @"cover2.0inch.png";
        if([SmarttagData type] == TAGTYPE_27_INCH){
            coverType = @"cover2.7inch.png";
        }
        UIImageView *overlayView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:coverType]];
        UIImagePickerController *imagePickerController = [[UIImagePickerController alloc]init];
        
        [imagePickerController setSourceType:UIImagePickerControllerSourceTypeCamera];
        [imagePickerController setCameraDevice:UIImagePickerControllerCameraDeviceFront];
        [imagePickerController setCameraOverlayView:overlayView];
        [imagePickerController setAllowsEditing:NO];
        [imagePickerController setDelegate:self];
        
        [self presentViewController:imagePickerController animated:YES completion:nil];
    }
    else
    {
        NSLog(@"camera invalid.");
    }
}
- (void)imagePickerController:(UIImagePickerController*)picker
        didFinishPickingImage:(UIImage*)image
                  editingInfo:(NSDictionary*)editingInfo
{
    //カメラコントローラーを隠す
    [self dismissModalViewControllerAnimated:YES];
    
    UIImage* originalImage = image;
    
    //画像の向きを補正
    UIGraphicsBeginImageContext(originalImage.size);
    [originalImage drawInRect:CGRectMake(0, 0, originalImage.size.width, originalImage.size.height)];
    originalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //切り抜いて２値化
    if([SmarttagData type] == TAGTYPE_27_INCH) {
        UIImage *processedImage = [self resizeImage:originalImage width:276 height:369];  //2.7
        processedImage = [self clipImage:processedImage rect:CGRectMake(6, 46, 264, 176)];   //2.7
        
        processedImage = [self binalize:processedImage];
        photoImage = processedImage;
        
        UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:SHOW_PHOTO inSection:0]];
        CellContentWithImageView *contentView = [[cell.contentView subviews] objectAtIndex:0];
        contentView.image = [self resizeImage:photoImage width:72 height:48];
        contentView.contentMode = UIViewContentModeScaleAspectFit;
        doImageFunction = YES;
        
    }else if([SmarttagData type] == TAGTYPE_20_INCH){
    
        UIImage *processedImage = [self resizeImage:originalImage width:212 height:284];  //2.0
        processedImage = [self clipImage:processedImage rect:CGRectMake(6, 52, 200, 96)];  //2.0
    
        processedImage = [self binalize:processedImage];
        photoImage = processedImage;
    
        UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:SHOW_PHOTO inSection:0]];
        CellContentWithImageView *contentView = [[cell.contentView subviews] objectAtIndex:0];


        contentView.image = [self resizeImage:photoImage width:100 height:48];
        contentView.contentMode = UIViewContentModeScaleAspectFit;
        doImageFunction = YES;

    }
    doImageFunction = YES;
}

//画像切り抜き
-(UIImage*)clipImage:(UIImage*)image rect:(CGRect)rect
{
    float scale = image.scale;
    CGRect cliprect = CGRectMake(rect.origin.x * scale, rect.origin.y * scale,
                                 rect.size.width * scale, rect.size.height * scale);
    CGImageRef srcImgRef = [image CGImage];
    
    CGImageRef imgRef = CGImageCreateWithImageInRect(srcImgRef, cliprect);
    UIImage* resultImage = [UIImage imageWithCGImage:imgRef scale:scale orientation:image.imageOrientation];
    
    CGImageRelease(imgRef);
    
    return resultImage;
}

-(UIImage*)resizeImage:(UIImage*)image width:(size_t)width height:(size_t)height
{
    /*
    CGImageRef imageRef = [image CGImage];
    size_t originW = CGImageGetWidth(imageRef);
    size_t originH = CGImageGetHeight(imageRef);
    
    NSLog(@"%d, %d, %d, %d", (int)originW, (int)originH, (int)width, (int)height);
    */
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    [image drawInRect:CGRectMake(0, 0, width, height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}
//画像の左右反転
- (UIImage *)mirrorImage:(UIImage *)img
{
    CGImageRef imgRef = [img CGImage];
    UIGraphicsBeginImageContext(img.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM( context, img.size.width, img.size.height);
    CGContextScaleCTM(context, -1.0, 1.0);
    CGContextDrawImage( context, CGRectMake( 0, 0, img.size.width, img.size.height), imgRef);
    UIImage *retImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return retImg;
}

//画像の２値化
- (UIImage *)binalize:(UIImage *)source
{
    // UIImageをCIImageに変換
    CIImage *filteredImage = [[CIImage alloc] initWithCGImage:source.CGImage];
    
    // トーンカーブフィルター
    //CIFilter *tonecurvefilter = [CIFilter filterWithName:@"CIToneCurve"];
    //[tonecurvefilter setDefaults];
    //[tonecurvefilter setValue:filteredImage forKey:kCIInputImageKey];
    //[tonecurvefilter setValue:[CIVector vectorWithX:0.0 Y:0.0] forKey:@"inputPoint0"];
    //[tonecurvefilter setValue:[CIVector vectorWithX:0.25 Y:0.225] forKey:@"inputPoint1"];
    //[tonecurvefilter setValue:[CIVector vectorWithX:0.50 Y:0.45] forKey:@"inputPoint2"];
    //[tonecurvefilter setValue:[CIVector vectorWithX:0.75 Y:0.725] forKey:@"inputPoint3"];
    //[tonecurvefilter setValue:[CIVector vectorWithX:1.0 Y:1.0] forKey:@"inputPoint4"];
    //filteredImage =  [tonecurvefilter outputImage];

    
    // モノクロフィルター
    CIFilter *filter = [CIFilter filterWithName:@"CIColorMonochrome"
                                  keysAndValues:
                        kCIInputImageKey, filteredImage,
                        @"inputColor", [CIColor colorWithRed:0.75 green:0.75 blue:0.75],
                        @"inputIntensity", [NSNumber numberWithFloat:1.0],
                        nil];
    filteredImage = filter.outputImage;
    
    // ポスタライズフィルター
    //    CIFilter *filter2 = [CIFilter filterWithName:@"CIColorPosterize"
    //                                   keysAndValues:
    //                         kCIInputImageKey, filteredImage,
    //                         @"inputLevels", [NSNumber numberWithFloat:2.0],
    //                         nil];
    //
    //    filteredImage = filter2.outputImage;
    

    
    // CIImageをUIImageに変換する
    // 画面に表示する。
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef imageRef = [ciContext createCGImage:filteredImage
                                          fromRect:[filteredImage extent]];
    //トリミング
    UIImage *outputImage  = [UIImage imageWithCGImage:imageRef
                                                scale:1.0f
                                          orientation:UIImageOrientationUp];

    
    //    UIImage* src = [UIImage imageNamed:@"icebraker.png"];
    IplImage* imgA = [self IplImageFromUIImage:outputImage];
    /** OpenCVによる画像処理　**/
    
    IplImage *imgB =[self IplImageFromUIImage:outputImage];
    DITHERING(imgA, imgB);
    
    //  IplImage *imgC =[self getImage:imgB];
    UIImage *imgProcessed = [self UIImageFromIplImage:imgB];
    
    
    //   使わなくなったものをリリースする。
    cvReleaseImage(&imgA);
    cvReleaseImage(&imgB);
    CGImageRelease(imageRef);
    
    
    return imgProcessed;
}

int GetAverage(int red, int green, int blue)
{
    //return (int)((float)(red + green + blue) / 3);
    //NTSC加重平均法
    return (int)((float)(red   * 0.298912f) +
                 (float)(green * 0.586611f) +
                 (float)(blue  * 0.114478f)  );
}

void DITHERING(IplImage *imgA,IplImage *dst)
{
    //
    //cvCopy(imgA,dst);
    //
    
    // NTSC加重平均法で均す
/*    for(int j = 0;j < dst->height; j++)
    {
        for(int i = 0;i < dst->width; i++)
        {
            int pixcelIndex  = j*dst->width + i;
            int rgbDataIndex = pixcelIndex * dst->nChannels;
            int avg = GetAverage(dst->imageData[rgbDataIndex+2],
                                 dst->imageData[rgbDataIndex+1],
                                 dst->imageData[rgbDataIndex+0]);
            
            dst->imageData[rgbDataIndex+0] = (char)avg;
            dst->imageData[rgbDataIndex+1] = (char)avg;
            dst->imageData[rgbDataIndex+2] = (char)avg;
            dst->imageData[rgbDataIndex+3] = (char)avg;
        }
    }
    
    return;
*/
    double e;
    for(int j = 0;j<dst->height;j++)
    {
        for(int i = 0;i<dst->widthStep;i++)
        {
            
            if( (unsigned char)(dst->imageData[j*dst->widthStep + i]) > (unsigned char)(127))
            {
                e = double(dst->imageData[j*dst->widthStep + i] - char (255));
                dst->imageData[j*dst->widthStep + i] = char (255);
            }else
            {
                e = double(dst->imageData[j*dst->widthStep + i]);
                dst->imageData[j*dst->widthStep + i] = char (0);
            }
            
            if ( i < dst->widthStep - 1)
            {
                //dst->imageData[j*dst->widthStep + i+dst->nChannels] += char(double(e)*(7/16.0));
                dst->imageData[j*dst->widthStep + i+dst->nChannels] += char(double(e)*(7/48.0));
            }
            
            if ( i < (dst->widthStep*2) - 1)
            {
                dst->imageData[j*dst->widthStep + i+(dst->nChannels * 2)] += char(double(e)*(5/48.0));
            }
            
            if ( j < dst->height - 1)
            {
                //dst->imageData[(j+1)*dst->widthStep + dst->nChannels] += char(double(e)*(5/16.0));
                dst->imageData[(j+1)*dst->widthStep + i] += char(double(e)*(7/48.0));
                
                if(i-(dst->nChannels * 2) > 0)
                {
                    dst->imageData[(j+1)*dst->widthStep + i-(dst->nChannels * 2)] += char(double(e)*(3/48.0));
                }
                
                if(i-dst->nChannels > 0)
                {
                    //dst->imageData[(j+1)*dst->widthStep + i-dst->nChannels] += char(double(e)*(3/16.0));
                    dst->imageData[(j+1)*dst->widthStep + i-dst->nChannels] += char(double(e)*(5/48.0));
                }
                if ( i+dst->nChannels < dst->widthStep)
                {
                    //dst->imageData[(j+1)*dst->widthStep + i+dst->nChannels] += char(double(e)*(1/16.0));
                    dst->imageData[(j+1)*dst->widthStep + i+dst->nChannels] += char(double(e)*(5/48.0));
                }
                
                if ( i < (dst->widthStep*2) - 1)
                {
                    dst->imageData[(j+1)*dst->widthStep + i+(dst->nChannels * 2)] += char(double(e)*(7/48.0));
                }
            }
            
            if ( j < dst->height - 2)
            {
                dst->imageData[(j+2)*dst->widthStep + i] += char(double(e)*(5/48.0));
                
                if(i-(dst->nChannels * 2) > 0)
                {
                    dst->imageData[(j+2)*dst->widthStep + i-(dst->nChannels * 2)] += char(double(e)*(1/48.0));
                }
                
                if(i-dst->nChannels > 0)
                {
                    dst->imageData[(j+2)*dst->widthStep + i-dst->nChannels] += char(double(e)*(3/48.0));
                }
                if ( i+dst->nChannels < dst->widthStep)
                {
                    dst->imageData[(j+2)*dst->widthStep + i+dst->nChannels] += char(double(e)*(3/48.0));
                }
                
                if ( i < (dst->widthStep*2) - 1)
                {
                    dst->imageData[(j+2)*dst->widthStep + i+(dst->nChannels * 2)] += char(double(e)*(1/48.0));
                }

            }
            
        }
    }
    
    return;
}

- (IplImage*)IplImageFromUIImage:(UIImage *)image
{
    CGImageRef imageRef = image.CGImage;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    IplImage *iplimage = cvCreateImage(cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4 );
    
    printf("width=%d\n",iplimage->width);
    printf("width=%d\n",iplimage->height);
    printf("width=%d\n",iplimage->depth);
    printf("width=%d\n",iplimage->widthStep);
    
    
    CGContextRef contextRef = CGBitmapContextCreate(
                                                    iplimage->imageData,
                                                    iplimage->width,
                                                    iplimage->height,
                                                    iplimage->depth,
                                                    iplimage->widthStep,
                                                    colorSpace,
                                                    kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef,
                       CGRectMake(0, 0, image.size.width, image.size.height),
                       imageRef);
    
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 4);
    cvCvtColor(iplimage, ret, CV_BGRA2RGBA);
    cvReleaseImage(&iplimage);
    
    return ret;
}
- (UIImage*)UIImageFromIplImage:(IplImage*)image
{
    CGColorSpaceRef colorSpace;
    colorSpace = CGColorSpaceCreateDeviceGray();

//    if (image->nChannels == 1)
//    {
//        colorSpace = CGColorSpaceCreateDeviceGray();
//    } else {
//        colorSpace = CGColorSpaceCreateDeviceRGB();
//        //BGRになっているのでRGBに変換
//        cvCvtColor(image, image, CV_BGRA2RGBA);
//    }
    
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(image->width,
                                        image->height,
                                        image->depth,
                                        image->depth * image->nChannels,
                                        image->widthStep,
                                        colorSpace,
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault
                                        );
    UIImage *ret = [UIImage imageWithCGImage:imageRef];
    
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return ret;
}


//スマートタグに画像を表示（撮影画像、文字兼用）
- (void)showImage:(UIImage *)image
{
    if(image == nil)
    {
        [self functionComplete];
        return;
    }
    
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(showImageComplete) name:ADAPTER_EVENT_SHOW_IMAGE_COMPLETE];
    [Adapter addObserver:self selector:@selector(showImageError:) name:ADAPTER_EVENT_ERROR];
    [Adapter showImage:image];
}

//エラー
-(void)showImageError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SHOW_IMAGE_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}

//完了
- (void)showImageComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SHOW_IMAGE_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
}





//URLの入力ダイアログの表示
- (void)setWriteURL
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:TITLE_INPUT_URL
													  message:nil
													 delegate:self
											cancelButtonTitle:nil
											otherButtonTitles:@"OK", nil];
	[alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    UITextField *tf = [alertView textFieldAtIndex:0];
    tf.text = writeURLText;
    tf.keyboardType = UIKeyboardTypeURL;
    tf.clearButtonMode = UITextFieldViewModeAlways;
	[alertView show];
}


//スマートタグにURLを書き込む
- (void)writeURL:(NSString *)url
{
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(writeURLtoSmartTagComplete) name:ADAPTER_EVENT_SAVE_URL_COMPLETE];
    [Adapter addObserver:self selector:@selector(writeURLtoSmartTagError:) name:ADAPTER_EVENT_ERROR];
    [Adapter saveURL:url];
}

//エラー
-(void)writeURLtoSmartTagError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SAVE_URL_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}

//完了
- (void)writeURLtoSmartTagComplete
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_SAVE_URL_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
}






//スマートタグに登録したURLを開く
- (void)openResisteredWebPage
{
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    [Adapter addObserver:self selector:@selector(openRegisteredWebPageComplete:) name:ADAPTER_EVENT_LOAD_URL_COMPLETE];
    [Adapter addObserver:self selector:@selector(openRegisteredWebPageError:) name:ADAPTER_EVENT_ERROR];
    [Adapter loadURL];
}
//エラー
-(void)openRegisteredWebPageError:(NSNotification *)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_LOAD_URL_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    NSString *errorText = [[notification userInfo] objectForKey:@"ERROR"];
    [self functionError:errorText];
}
//完了
- (void)openRegisteredWebPageComplete:(NSNotification*)notification
{
    [Adapter removeObserver:self name:ADAPTER_EVENT_LOAD_URL_COMPLETE];
    [Adapter removeObserver:self name:ADAPTER_EVENT_ERROR];
    [self functionComplete];
    
    readURLText = [[notification userInfo] objectForKey:@"URL"];
    NSRange range1 = [readURLText rangeOfString:@"http://"];
    NSRange range2 = [readURLText rangeOfString:@"https://"];
    if (range1.length > 0 || range2.length > 0)
    {
        [self confirmOpenURL:readURLText];
    }
    else
    {
        [self alertNotURL];
    }

}
//ブラウザを開く確認ダイアログを表示
-(void)confirmOpenURL:(NSString *)url
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:TITLE_OPEN_URL
                                                        message:url
                                                       delegate:self
                                              cancelButtonTitle:@"CANCEL"
                                              otherButtonTitles:@"OK", nil];
    [alertView show];
}
//取得文字列がURLでない場合は警告
-(void)alertNotURL
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:TITLE_ERROR_URL
                                                        message:nil
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"OK", nil];
    [alertView show];
}









- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    if([alertView.title isEqualToString:TITLE_INPUT_URL])
    {
        NSString *inputText = [[alertView textFieldAtIndex:0] text];
        return (BOOL)([inputText length] >= 1);
    }
    else
    {
        return YES;
    }
}
-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if([alertView.title isEqualToString:TITLE_INPUT_URL])
    {
        writeURLText = [[alertView textFieldAtIndex:0] text];
        UITableViewCell *cell = [_menuTable cellForRowAtIndexPath:[NSIndexPath indexPathForRow:WRITE_URL inSection:0]];
        cell.detailTextLabel.text = writeURLText;
        [self doFunction];
    }
    else if([alertView.title isEqualToString:TITLE_ERROR_URL])
    {
        [self functionComplete];
    }
    else if([alertView.title isEqualToString:TITLE_OPEN_URL])
    {
        if(buttonIndex == 1)
        {
            NSURL *url = [NSURL URLWithString:readURLText];
            [[UIApplication sharedApplication] openURL:url];
        }
        else
        {
            [self functionComplete];
        }
    }
    else if([alertView.title isEqualToString:TITLE_ERROR])
    {
        [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(restartPollingAfterError) userInfo:nil repeats:NO];
    }
}

- (void)restartPollingAfterError
{
    [Adapter startPolling];
}



//エラーアラート表示
- (void)showErrorAlert:(NSString *)text
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:TITLE_ERROR
                                                    message:text
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:@"OK", nil];
    [alert show];
}



@end
