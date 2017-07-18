//
//  PlayerManager.m
//  MusicDemo


#import "PlayerManager.h"
#import <AVFoundation/AVFoundation.h>

#ifdef DEBUG
#  define LogEx( s, ... ) NSLog( @"<%@:(%s,%d)> \n%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )

#else
#define LogEx(s, ...) ;

#endif

#define isValidString(string)               (string && [string isEqualToString:@""] == NO)

@interface PlayerManager()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *item;
@property (nonatomic, strong) NSURL *playingURL;
@end

@implementation PlayerManager
// instance method
+ (instancetype)sharedInstance
{
    static PlayerManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[PlayerManager alloc] init];
    });
    return manager;
}

// default init
- (instancetype)init
{
    self = [super init];
    if (self) {
        _player = [[AVPlayer alloc] init];
    }
    return self;
}

/**
 Play music  by URL
 
 @param voiceURL voiceURL description
 */
- (void)playWithVoiceURL:(NSURL *)voiceURL {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [audioSession setCategory :AVAudioSessionCategoryPlayback error:&err];
    
    if (!self.playingURL || ![self.playingURL isEqual:voiceURL]) {
        [self restPlay];
        [self playerSetWithURL:voiceURL];
        self.playingURL = voiceURL;
    } else {
        if (self.status == ETPlayer_Pause) {
            [self resumePlay];
        } else if (self.status == ETPlayer_FinishedPlay || self.status == ETPlayer_Stop) {
            [self seekToNewTime:0];
            [self resumePlay];
        }
    }
}

- (void)playerSetWithURL:(NSURL *)url {

    if (!url || !isValidString(url.absoluteString)) {
        LogEx(@"------ play url is error");
        return;
    }
    
        if (self.item) { // if avplayer has a item
            [self removeObserverFromPlayerItem:self.item];
            self.item = nil;
            AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
            [_player replaceCurrentItemWithPlayerItem:item];
            self.item = item;

        } else { // init new item
            AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
            _player = [AVPlayer playerWithPlayerItem:item];
            self.item = item;
        }
        [self addObserverToPlayerItem:self.item];
        [_player play];
}

// 播放
- (void)resumePlay
{
    [_player play];
    LogEx(@"=======  play resume =======");

}
// 暂停
- (void)pause
{
    [_player pause];
    self.status = ETPlayer_Pause;
    LogEx(@"=======  play pause =======");
    if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_Pause]; }
}

// stop
- (void)stop {
    [_player pause];
    [self seekToNewTime:0];
    self.status = ETPlayer_Stop;
    LogEx(@"=======  play stop =======");
    if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_Stop]; }
}
// 跳转到某一秒
- (void)seekToNewTime:(NSUInteger)newTime
{
    /*
     value 代表的是总帧数
     timescale 代表的是每秒有多少帧
     */
    // 使用currentTime为了获取当前的歌曲每秒有多少帧，因为每一首歌的品质不同，每秒有多少帧也不同
    CMTime time = _player.currentTime;
    time.value = newTime * time.timescale;
    [_player seekToTime:time];
}
- (NSInteger)currentTime
{
    CMTime time = _player.currentTime;
    // 当AVPlayer还没有读取到歌曲信息的时候，此时歌曲的当前时间为0，并且CMTime结构体的四个成员变量都是0，
    // 数学中0不可作为分母，同样代码里面0作为分母也会出问题。
    if (time.timescale == 0) {
        return 0;
    }
    return time.value / time.timescale;
}

- (NSInteger)finishTime
{

    CMTime time = _player.currentItem.duration;
    if (time.timescale == 0) {
        return 0;
    }
    return time.value / time.timescale;
    
// to get correct duration time
//    if (self.player && self.player.currentItem && self.player.currentItem.asset) {
//        return  CMTimeGetSeconds(self.player.currentItem.asset.duration);
//
//    } else{
//        return 0;
//    }
//    

//    AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:self.playingURL options:nil];
//    CMTime audioDuration = audioAsset.duration;
//    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
//    return (NSInteger)audioDurationSeconds;
}

- (BOOL)isPlaying
{
    // 可以根据值去判断播放还是暂停
    if (_player.rate == 0.0) {
        return NO;
    }
    return YES;
}

- (void)restPlay {
    if ([self isPlaying]) {
        [self pause];
    } else if (self.item) {
        [self removeObserverFromPlayerItem:self.item];
        self.item = nil;
    }
    self.status = ETPlayer_Original;
    LogEx(@"=======  player reset =======");
}
/**
 *  给AVPlayerItem添加监控
 *
 *  @param playerItem AVPlayerItem对象
 */
- (void)addObserverToPlayerItem:(AVPlayerItem *)playerItem
{
    if (playerItem) {
        [playerItem addObserver:self
                     forKeyPath:@"status"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
        //监控网络加载情况属性
        [playerItem addObserver:self
                     forKeyPath:@"loadedTimeRanges"
                        options:NSKeyValueObservingOptionNew
                        context:nil];
        //给AVPlayerItem添加播放完成通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackFinished:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:playerItem];
    }
}

- (void)removeObserverFromPlayerItem:(AVPlayerItem *)playerItem
{
    if (playerItem) {
        [playerItem removeObserver:self forKeyPath:@"status"];
        [playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [[NSNotificationCenter defaultCenter]removeObserver:self
                                                       name:AVPlayerItemDidPlayToEndTimeNotification
                                                     object:playerItem];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    AVPlayerItem *playerItem = object;
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerStatus status = [[change objectForKey:@"new"] intValue];
        switch (status) {
            case AVPlayerStatusUnknown:
            {
                self.status = ETPlayer_UnkonwError;
                LogEx(@"=======  player UnkonwError =======");
                if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_UnkonwError]; }
            }
                break;
            case AVPlayerStatusReadyToPlay:
            {
                self.status = ETPlayer_ReadyToPlay;
                LogEx(@"======= ready to play =======");
                if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_ReadyToPlay]; }
               
                CMTime time = _player.currentItem.duration;
                float value1 = time.value / time.timescale;
                
                float value2 = CMTimeGetSeconds(self.player.currentItem.asset.duration);

                
                AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:self.playingURL options:nil];
                CMTime audioDuration = audioAsset.duration;
                float value3 = CMTimeGetSeconds(audioDuration);
                
                NSLog(@"正在播放，_player.currentItem.duration 总长度:%.2f", value1);
                NSLog(@"正在播放，_player.currentItem.asset.duration总长度:%.2f", value2);
                NSLog(@"正在播放，audioAsset.duration 总长度:%.2f", value3);

            }
                break;
            case AVPlayerStatusFailed:
            {
                self.status = ETPlayer_PlayFailed;
                LogEx(@"=======  play failed =======");
                if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_PlayFailed]; }
            }
                break;
            default:
                break;
        }
        
    } else if([keyPath isEqualToString:@"loadedTimeRanges"]) {
        double timeInterval = [self availableDuration];
        CMTime duration = playerItem.duration;
        double totalDuration = CMTimeGetSeconds(duration);
        
        NSLog(@"timeInterval:%f",timeInterval);
        NSLog(@"totalDuration:%f",totalDuration);
        
        if (timeInterval < 1.5 * totalDuration) {
            self.status = ETPlayer_Loading;
            LogEx(@"=======  play loding =======");
            if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_Loading]; }
        }else if ([self isPlaying]) {
            self.status = ETPlayer_Playing;
            LogEx(@"=======  playing =======");
            if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_Playing]; }
        } else {
            self.status = ETPlayer_Loading;
            LogEx(@"=======  play loading =======");
            if ([self respondsDelegate]) { [self.delegate currentPlayerStatus:ETPlayer_Loading]; }
        }
    }
}

- (double)availableDuration{
    NSArray *loadedTimeRanges = self.player.currentItem.loadedTimeRanges;
    NSValue *value = loadedTimeRanges.firstObject;
    CMTimeRange timeRange = value.CMTimeRangeValue;
    double startSeconds = CMTimeGetSeconds(timeRange.duration);
    double durationSeconds = CMTimeGetSeconds(timeRange.duration);
    return startSeconds + durationSeconds;
}

- (BOOL)respondsDelegate {
    if (self.delegate && [self.delegate respondsToSelector:@selector(currentPlayerStatus:)]) {
        return YES;
    }
    return NO;
}

// listen play finish
- (void)playbackFinished:(NSNotification *)notification {
    LogEx(@"=======  play finish =======");
    if ([self respondsDelegate]) {
        [self.delegate currentPlayerStatus:ETPlayer_FinishedPlay];
    }
    self.status = ETPlayer_FinishedPlay;
}


@end
