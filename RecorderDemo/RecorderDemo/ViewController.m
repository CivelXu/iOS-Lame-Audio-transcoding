//
//  ViewController.m
//  RecorderDemo
//
//  Created by xuxiwen on 2017/7/13.
//  Copyright © 2017年 xuxiwen. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "PlayerManager.h"
#import "ConvertAudioFile.h"

#define isValidString(string)               (string && [string isEqualToString:@""] == NO)
#define ETRECORD_RATE 11025.0
#define ENCODE_MP3    1


@interface ViewController ()<AVAudioRecorderDelegate>

@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@property (nonatomic,strong) NSString *mp3Path;
@property (nonatomic,strong) NSString *cafPath;

@property (nonatomic, strong) NSTimer *timer;
@property (weak, nonatomic) IBOutlet UIButton *recordButton;

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;

- (IBAction)recoredButton:(id)sender;

@end

@implementation ViewController
{
    NSInteger time;
}
- (void)viewDidLoad {
    [super viewDidLoad];
 }

/**
 *  获得录音机对象
 *
 *  @return 录音机对象
 */
- (AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //7.0第一次运行会提示，是否允许使用麦克风
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *sessionError;
        //AVAudioSessionCategoryPlayAndRecord用于录音和播放
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        if(session == nil)
            NSLog(@"Error creating session: %@", [sessionError description]);
        else
            [session setActive:YES error:nil];
        
        //创建录音文件保存路径
        NSURL *url= [self getSavePath];
        //创建录音格式设置
        NSDictionary *setting = [self getAudioSetting];
        //创建录音机
        NSError *error=nil;
        _audioRecorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate=self;
        _audioRecorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
        [_audioRecorder prepareToRecord];
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}

/**
 *  取得录音文件设置
 *
 *  @return 录音设置
 */
- (NSDictionary *)getAudioSetting{
    NSMutableDictionary *dicM = [NSMutableDictionary dictionary];
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    [dicM setObject:@(ETRECORD_RATE) forKey:AVSampleRateKey];
    [dicM setObject:@(2) forKey:AVNumberOfChannelsKey];
    [dicM setObject:@(16) forKey:AVLinearPCMBitDepthKey];
    [dicM setObject:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    return dicM;
}

/**
 *  取得录音文件保存路径
 *
 *  @return 录音文件路径
 */
-(NSURL *)getSavePath{
    //  在Documents目录下创建一个名为FileData的文件夹
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject] stringByAppendingPathComponent:@"AudioData"];
    NSLog(@"%@",path);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    if(!(isDirExist && isDir))
        
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"创建文件夹失败！");
        }
        NSLog(@"创建文件夹成功，文件路径%@",path);
    }
    NSString *fileName = @"record";
    NSString *cafFileName = [NSString stringWithFormat:@"%@.caf", fileName];
    NSString *mp3FileName = [NSString stringWithFormat:@"%@.mp3", fileName];
    
    NSString *cafPath = [path stringByAppendingPathComponent:cafFileName];
    NSString *mp3Path = [path stringByAppendingPathComponent:mp3FileName];
    
    self.mp3Path = mp3Path;
    self.cafPath = cafPath;
    
    NSLog(@"file path:%@",cafPath);
    
    NSURL *url=[NSURL fileURLWithPath:cafPath];
    return url;
}

- (void)cleanCafFile {
    
    if (isValidString(self.cafPath)) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDir = FALSE;
        BOOL isDirExist = [fileManager fileExistsAtPath:self.cafPath isDirectory:&isDir];
        if (isDirExist) {
            [fileManager removeItemAtPath:self.cafPath error:nil];
            NSLog(@"  xxx.caf  file   already delete");
        }
    }
}

- (void)cleanMp3File {
    
    if (isValidString(self.mp3Path)) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDir = FALSE;
        BOOL isDirExist = [fileManager fileExistsAtPath:self.mp3Path isDirectory:&isDir];
        if (isDirExist) {
            [fileManager removeItemAtPath:self.mp3Path error:nil];
            NSLog(@"  xxx.mp3  file   already delete");
        }
    }
}


- (void)convertMp3 {
    
    
        [[ConvertAudioFile sharedInstance] conventToMp3WithCafFilePath:self.cafPath
                                                           mp3FilePath:self.mp3Path
                                                            sampleRate:ETRECORD_RATE callback:^(BOOL result)
        {
            NSLog(@"---- 转码完成  --- result %d  ---- ", result);
        }];;
 

}


- (IBAction)recoredButton:(id)sender {
    
    // 重置录音机
    if (_audioRecorder) {
        [self cleanMp3File];
        [self cleanCafFile];
        _audioRecorder = nil;
        time = 0;
        [self destoryTimer];
    }
    
    if (![self.audioRecorder isRecording]) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *sessionError;
        //AVAudioSessionCategoryPlayAndRecord用于录音和播放
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        if(session == nil)
            NSLog(@"Error creating session: %@", [sessionError description]);
        else
            [session setActive:YES error:nil];
        
        
        
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(record)
                                                    userInfo:nil
                                                     repeats:YES];
        [self.audioRecorder record];

         NSLog(@"录音开始");
        
#if ENCODE_MP3
         [[ConvertAudioFile sharedInstance] conventToMp3WithCafFilePath:self.cafPath
                                                           mp3FilePath:self.mp3Path
                                                            sampleRate:ETRECORD_RATE
                                                              callback:^(BOOL result)
         {
             if (result) {
                 NSLog(@"mp3 file compression sucesss");
             }
         }];
#endif
        
    } else {
        
        NSLog(@"is  recording now  ....");
    }

}

- (void)record {
    time ++;
    self.timeLabel.text = [self timeFormatted:(int)time];
}


- (IBAction)stopRecord:(id)sender {
 
    if ([self.audioRecorder isRecording]) {
        NSLog(@"完成");
        [self destoryTimer];
        [self.audioRecorder stop];
    }

#if !ENCODE_MP3
    [ConvertAudioFile conventToMp3WithCafFilePath:self.cafPath
                                      mp3FilePath:self.mp3Path
                                       sampleRate:ETRECORD_RATE
                                         callback:^(BOOL result) {
                                             NSLog(@"转码结果 ------ %d", result);
    }];
    
#endif
}



- (IBAction)playVoice:(id)sender {
    
    if ([self.audioRecorder isRecording]) {
        NSLog(@"--------  正在录制中...");
        [self stopRecord:nil];
        return;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:self.cafPath isDirectory:&isDir];
    if (!isDirExist) {
        NSLog(@"--------  录音文件不存在...");
        return;
    }
    
    NSURL *url = [NSURL fileURLWithPath:self.mp3Path];
    
    [[PlayerManager sharedInstance] playWithVoiceURL:url];
    
    if (self.timer) {
        [self destoryTimer];
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                   target:self
                                                 selector:@selector(play)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)play {
     self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@",
                            [self timeFormatted:[PlayerManager sharedInstance].currentTime],
                            [self timeFormatted:[PlayerManager sharedInstance].finishTime]];
}

- (IBAction)pausePaly:(id)sender {
    [[PlayerManager sharedInstance] pause];
}


- (void)destoryTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
        NSLog(@"----- timer destory");
    }
}


- (NSString *)timeFormatted:(NSInteger)totalSeconds {
    
    NSInteger seconds = totalSeconds % 60;
    NSInteger minutes = (totalSeconds / 60) % 60;
    NSInteger hours = totalSeconds / 3600;
    if (hours <= 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld",(long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hours, (long)minutes, (long)seconds];
}

/* audioRecorderDidFinishRecording:successfully: is called when a recording has been finished or stopped. This method is NOT called if the recorder is stopped due to an interruption. */
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) {
        NSLog(@"----- 录音  完毕");
        
#if ENCODE_MP3
        [[ConvertAudioFile sharedInstance] sendEndRecord];;
#endif
        
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
