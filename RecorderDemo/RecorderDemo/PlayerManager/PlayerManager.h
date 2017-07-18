//
//  PlayerManager.h
//  MusicDemo




#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    ETPlayer_Original,
    ETPlayer_UnkonwError,
    ETPlayer_ReadyToPlay,
    ETPlayer_Playing,
    ETPlayer_PlayFailed,
    ETPlayer_Pause,
    ETPlayer_Stop,
    ETPlayer_Loading,
    ETPlayer_FinishedPlay,
} ETPlayerStatus;

@protocol ETPlayerDelagate <NSObject>
@optional
- (void)currentPlayerStatus:(ETPlayerStatus)playerStatus;
@end

@interface PlayerManager : NSObject

// instance method
+ (instancetype)sharedInstance;

/**
 Play music  by URL
 
 @param voiceURL voiceURL description
 */
- (void)playWithVoiceURL:(NSURL *)voiceURL;

// pause
- (void)pause;
// stop
- (void)stop;
// seek to time
- (void)seekToNewTime:(NSUInteger)newTime;
// judge is Playing now
- (BOOL)isPlaying;
// rest palyer
- (void)restPlay;

// 当前时间(秒数)
@property (nonatomic, assign) NSInteger currentTime;
// 总时间(秒数)
@property (nonatomic, assign) NSInteger finishTime;

@property (nonatomic, assign) ETPlayerStatus status;

@property (nonatomic, weak) id<ETPlayerDelagate> delegate;
@end
