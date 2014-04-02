//
//  TopViewController.h
//  SmartTagApp
//

#import <UIKit/UIKit.h>
#import "ShowInputTextViewController.h"

#define MESSAGE_TOUCH_SMARTTAG @"スマートタグに近づけてください"
#define MESSAGE_CONNECTING     @"通信中"
#define MESSAGE_COMPLETE       @"完了しました"
#define MESSAGE_ERROR          @"エラーが発生しました"
#define MESSAGE_CANCEL         @"キャンセルしました"

#define TITLE_INPUT_URL        @"URLを入力してください"
#define TITLE_ERROR_URL        @"URLが登録されていません"
#define TITLE_OPEN_URL         @"ブラウザで開きます"
#define TITLE_ERROR            @"エラー"



typedef NS_ENUM(NSInteger, SarttagFunction) {
    SHOW_DEMO_IMAGE  = 0, // デモ画像を表示
    SHOW_PHOTO       = 1, // 撮影画像を表示
    SHOW_INPUT_TEXT  = 2, // 入力文字を表示
    SAVE_LAYOUT      = 3, // 表示画像を登録
    SHOW_LAYOUT      = 4, // 登録画像を表示
    WRITE_URL        = 5, // URL書き込み
    READ_URL         = 6, // ウェブを開く
    CLEAR_DISPLAY    = 7, // ディスプレイクリア
};

@interface SmarttagReaderViewController : UIViewController  <ShowInputTextDelegate, UIActionSheetDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    NSArray *dataSource;
    int tagType;
    UIActionSheet *actionSheet;
}

@property (weak, nonatomic) IBOutlet UIImageView *smartTagImage20;
@property (weak, nonatomic) IBOutlet UIImageView *smartTagImage27;
@property (weak, nonatomic) IBOutlet UILabel *tagID;
@property (weak, nonatomic) IBOutlet UITableView *menuTable;
@property (weak, nonatomic) IBOutlet UILabel *message;

- (IBAction) backButtonClicked:(id) sender;

//debug

@end
