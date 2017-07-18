# iOS 使用 Lame 转码 MP3 的最正确姿势

## 前言

* 最近在项目中, 做有关 **AVAudioRecorder** 的录音开发, 需要把录制的格式转成 MP3, 遇到了转码之后的MP3文件, 无法获取正确的时长问题. 
* 为了解决这个问题, 真的是反复来修改录音配置, 浪费了不知道多少的时间来分析这个问题. 
* 中间我去某某群去找大神提问问题,结果遭到了鄙视, 都统统质疑我的录音配置, 最后甩给我一个demo, 结果我一测试, 也是一样的问题, 我就呵呵了.
* 所以, 我今天来写一篇文章来认真剖析这个问题, 为什么起名 ? **iOS 使用 Lame 转码 MP3 的最正确姿势 !** 是因为我在百度搜索到的各种有关于 **Lame** 转码的代码, 至少很大一部分 都是不完全正确的.
 
## 概述

我将会在本篇文章分析以下几点内容

* AVAudioRecorder 配置 和 Lame 编码压缩配置 
* 解决录音时长读取不正确的问题
* 边录制边转码的实现
* 测试 Demo

## AVAudioRecorder 配置 和 Lame 编码压缩配置
### AVAudioRecorder 配置的注意事项


> 关于 AVAudioRecorder 录音的相关配置 和 Lame 包的编译工作, 这里忽略不讲, 主要是想说一下需要注意的地方

* Lame 的转码压缩, 是把录制的 PCM 转码成 MP3, 所以录制的 `AVFormatIDKey` 设置成 `kAudioFormatLinearPCM` , 生成的文件可以是 caf 或者 wav.
* [caf](http://baike.baidu.com/link?url=TsCl2mxLZvWORN0CnhwPqjxElPDDREWgTyVrIkxWHyoOjbtYnn2kSW2qaliPHSUCHNOyNFbjRGfKqwmkgn08WK) 文件是 Mac OS X 原本支持的众多音频格式中最新增加的一种. iPhone 短信就是这种格式, 录制出的文件会比较大.
* `AVNumberOfChannelsKey` 必须设置为双声道, 不然转码生成的 MP3 会声音尖锐变声.
* `AVSampleRateKey` 必须保证和转码设置的相同.

### Lame 编码压缩 的相关配置

- 我们需要录音源文件路径和生成MP3的路径 `FILE *pcm`  和 `FILE *mp3`, 

```
//source 被转换的音频文件位置
FILE *pcm = fopen([cafFilePath cStringUsingEncoding:1], "rb");  
//skip file header 跳过 PCM header 能保证录音的开头没有噪音 
fseek(pcm, 4*1024,  SEEK_CUR); 
//output 输出生成的Mp3文件位置
FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:1], "wb+");  
```

* 通过 `fopen` 需要注意打开文件的模式. 👇 是扩展的 的 C 语言的 文件打开模式, 为什么要说这些, 比如 我使用 wb 来打开 mp3, 就意味着我只允许写数据, 而如果你有对文件的读取操作,将会出现错误, 这也是我被坑过的地方. 
              
```
C 语言的 文件打开模式

w+以纯文本方式读写，而wb+是以二进制方式进行读写。
mode说明：
w 打开只写文件，若文件存在则文件长度清为0，即该文件内容会消失。若文件不存在则建立该文件。
w+ 打开可读写文件，若文件存在则文件长度清为零，即该文件内容会消失。若文件不存在则建立该文件。
wb 只写方式打开或新建一个二进制文件，只允许写数据。
wb+ 读写方式打开或建立一个二进制文件，允许读和写。
r 打开只读文件，该文件必须存在，否则报错。
r+ 打开可读写的文件，该文件必须存在，否则报错。
rb+ 读写方式打开一个二进制文件，只允许读写数据。
a 以附加的方式打开只写文件。若文件不存在，则会建立该文件，如果文件存在，写入的数据会被加到文件尾，即文件原先的内容会被保留。（EOF符保留）
a+ 以附加方式打开可读写的文件。若文件不存在，则会建立该文件，如果文件存在，写入的数据会被加到文件尾后，即文件原先的内容会被保留。 （原来的EOF符不保留）
ab+ 读写打开一个二进制文件，允许读或在文件末追加数据。
加入b 字符用来告诉函数库打开的文件为二进制文件，而非纯文字文件。
```

* 然后是 `lame_init()` 来初始化, ` lame_set_num_channels(lame,1)` 默认转码为2双通道, 设置单声道会更大程度减少压缩后文件的体积.
* 接下来 是执行一个 do while 的循环来反复读取 `FILE* stream ` , 直到 read != 0 , 结束转码,释放  `lame_close(lame); fclose(mp3);  fclose(pcm);`

## 解决录音时长读取不正确的问题

> Lame 的转码配置网上有很多, 网上可以搜到很多相关的代码, 作为小白 copy 使用, 由于不懂源码实现,直接拿来用就出现了不可预料的问题. 我出现的播放时间不准确的问题, 无论是 AVPlayer 或者 AVAudioPlayer 均无法读取正确的长度, 要么是多几秒, 要么是少几秒, 还可能是超过10s的的误差, 但是播放的过程中, 定时器的计数 会和 总时间显示不吻合, 就比如 一个显示 2:30 的录音, 活生生 放到了 2:50, 你能想象是多么的尴尬Bug.

### 问题猜测

**我把录制完成的文件, 使用 iTunes 来播放可以显示出正确的长度, 但是使用 QuickTime Player 会出现和 AVPlayer 一样的错误时长 !!!**

- 所以分析造成这个问题的原因可能是: 
 *  1. AVPlayer 不能正确读取长度
 *  2. MP3的编码出现了错误...

- 然后网上也有人遇到了同样的问题,给出的解决方法是换一种 AVPlayer 读取方法:
我总结了 AVPlayer 获取总时长的以下方法 ,结果测试 结果都是相近, 

* way 1

```   
 CMTime time = _player.currentItem.duration;
    if (time.timescale == 0) {
        return 0;
    }
    return time.value / time.timescale;
```
    
* way 2

```
    if (self.player && self.player.currentItem && self.player.currentItem.asset) {
        return  CMTimeGetSeconds(self.player.currentItem.asset.duration);

    } else{
        return 0;
    }
    
```

* way 3
 
```
    AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL:self.playingURL options:nil];
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
    return (NSInteger)audioDurationSeconds;
```

- 其中 , 使用 [Asset](http://blog.csdn.net/qingyuan159/article/details/53085302) 可以解决获取总时间是 NA 的这种错误情况. 实际中我并没有出现过.
- 我的测试中 AVPlayer 使用这几个方法, 均无法得到正确的值, 所以应该就是生成文件的问题了.

### 了解MP3编码格式

然后,通过对[MP3编码格式](http://blog.csdn.net/xiahouzuoxin/article/details/7860631)调研, 了解到如下信息:

* MP3使用的是动态码率方式，而这种方式每一帧的长度应该是不等的。那会不会是 **AVPlayer** 是把文件当做每帧相等的方式来计算的总时间，所以才不对？
* 不断输出 AVPlayer duration来看, 每次都会有不同的结果, 而 AVPlayer 是支持Mp3 VBR格式文件播放的。所以应该还是我们的生成的文件有问题
* 了解到 MP3 VBR头这个东西,有它记录了整个文件的帧总数量，就能直接算出duration.所以是不是我们Lame编码的时候,没有写入 VBR 头 呢.

### Lame 源码分析


* 搜索 Lame 源码 **VBR**关键字可以得到

```
/*
  1 = write a Xing VBR header frame.
  default = 1
  this variable must have been added by a Hungarian notation Windows programmer :-)
*/
int CDECL lame_set_bWriteVbrTag(lame_global_flags *, int);
int CDECL lame_get_bWriteVbrTag(const lame_global_flags *);
```

* 源码写的很简单, 就是设置了 `gfp->write_lame_tag`值, 看看所有调用 `write_lame_tag` 的地方吧。第一个就找到了`lame_encode_mp3_frame(..)`函数。这不就是用来每次灌buffer给lame做MP3编码的方法嘛！也就是说每次都会给给帧添加VBR信息，这和之前看的编码资料描述的一样。

* 接下来, 就是需要找到写入VBR头的函数, 搜索源码可得 `PutLameVBR()` 被调用在`lame_get_lametag_frame()`函数里, 然后我们来看看这个函数:


```
/*
 * OPTIONAL:
 * lame_mp3_tags_fid will rewrite a Xing VBR tag to the mp3 file with file
 * pointer fid.  These calls perform forward and backwards seeks, so make
 * sure fid is a real file.  Make sure lame_encode_flush has been called,
 * and all mp3 data has been written to the file before calling this
 * function.
 * NOTE:
 * if VBR  tags are turned off by the user, or turned off by LAME because
 * the output is not a regular file, this call does nothing
 * NOTE:
 * LAME wants to read from the file to skip an optional ID3v2 tag, so
 * make sure you opened the file for writing and reading.
 * NOTE:
 * You can call lame_get_lametag_frame instead, if you want to insert
 * the lametag yourself.
*/
void CDECL lame_mp3_tags_fid(lame_global_flags *, FILE* fid);
```

* 原来这个函数是应该在lame_encode_flush()之后调, 当所有数据都写入完毕了再调用。仔细想想也很合理, 这时才能确定文件的总帧数。

### 问题解决

* 现在的思路就比较清晰了, 由于在Lame编码的过程中, 我们没有对VBR头进行写入, 导致了 AVPlayer duration 以每帧相同的方式来计算出现的错误.
* 解决方法是, 在lame文件全部写入之后, lame释放之前, 使用 `lame_mp3_tags_fid` 写入 VBR 头文件, 测试通过, 读取时间正常.
* 而这行代码 `lame_mp3_tags_fid` 我在 网上搜索的各种配置中发现都没有写.

## 边录制边转码的实现

> 通常我们是在录制结束之后, 再进行转码; 当录制的时间较长, 会消耗的时间比较长. 用户需要等待转码结束后,才能操作; 但是如果我们使用边录制,边转码的方式, 开另外一个线程同时进行转码,则几乎没有等待的时间,效率上会比较的高.
    
    
* 核心代码实现
    
```
            do {
                curpos = ftell(pcm);
                long startPos = ftell(pcm);
                fseek(pcm, 0, SEEK_END);
                long endPos = ftell(pcm);
                long length = endPos - startPos;
                fseek(pcm, curpos, SEEK_SET);
                
                if (length > PCM_SIZE * 2 * sizeof(short int)) {
                    
                    if (!isSkipPCMHeader) {
                        //Uump audio file header, If you do not skip file header
                        //you will heard some noise at the beginning!!!
                        fseek(pcm, 4 * 1024, SEEK_CUR);
                        isSkipPCMHeader = YES;
                        NSLog(@"skip pcm file header !!!!!!!!!!");
                    }
                    
                    read = (int)fread(pcm_buffer, 2 * sizeof(short int), PCM_SIZE, pcm);
                    write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
                    fwrite(mp3_buffer, write, 1, mp3);
                    NSLog(@"read %d bytes", write);
                } else {
                    [NSThread sleepForTimeInterval:0.05];
                    NSLog(@"sleep");
                }
                
            } while (! weakself.stopRecord);
```

* 边录边转码, 只是我们在录制结果后,重新开一个线程来进行文件的转码, 
* 当录音进行中时, 会持续读取到指定大小文件,进行编码, 读取不到,则线程休眠
* 在 while 的条件中, 我们收到 录音结束的条件,则会结束 do while 的循环.
* 我们需要在录制结束后发送一个信号, 让 do while 跳出循环

## 测试 Demo
    
> 为了让遇到相同问题的人, 能够更加对这些问题有一点的了解, 我会 在这里贴一个我测试的Demo 这只是一个实例程序, 并不具备完整的逻辑功能, 请熟知.

- 关于Demo, 可以在 ViewController 中 `#define ENCODE_MP3 1` 使用 1 和 0 , 来测试普通转码 和 边录制 边转码.
- `ConvertAudioFile` 是录音转码封装的源码 
- 边录边转的用法 

```
        [[ConvertAudioFile sharedInstance] conventToMp3WithCafFilePath:self.cafPath
                                                           mp3FilePath:self.mp3Path
                                                            sampleRate:ETRECORD_RATE callback:^(BOOL result)
        {
            NSLog(@"---- 转码完成  --- result %d  ---- ", result);
        }];;
        
``` 

- 录制完成转码的用法

```
    [ConvertAudioFile conventToMp3WithCafFilePath:self.cafPath
                      mp3FilePath:self.mp3Path
                       sampleRate:ETRECORD_RATE callback:^(BOOL result)
     {
         NSLog(@"---- 转码完成  --- result %d  ---- ", result);
     }];
        
```

- Demo 见 文章底部, 如果Demo 有什么不理解 和 不准确的地方,还麻烦指正...

## 结语

> 由于时间有限, 我并不会 写太多细致的内容, 只是对这几天的研究做一个总结,和列举一些注意事项,如果在做音频录制转码中遇到相同的问题,则会有比较大的帮助.

### 总结

这次解决这个问题,让我受益匪浅, 很多地方的收获是超过问题本身的:

* 在使用别人的示范代码时,如果不进行一定的剖析;当出现问题的时间,会比较的难判断问题的来源
* iOS的相关技术博客,现在网上可以搜到很多相关示范代码, 但是由于很多人可能也是贴出了并不是很准确的东西, 相关给别人带来了错误的示范.
* 作为 iOS 开发者, 对很多东西,如果想要有更加深层次的理解,则需要 1. 计算机基础扎实 2. iOS底层理解够深 3.架构设计模式理解够深 4.代码平时写的必须够优雅 
* Google 会比 Baidu 靠谱呀; 虽然我之前也是这么想的,但这次对我有帮助的文章均来自 Google, 相反Baidu 给了很多错误的示范.

### Link

* [Demo - GitHub](https://github.com/CivelXu/iOS-Lame-Audio-transcoding.git)
* [简书](http://www.jianshu.com/p/971fff236881)
* [个人博客](http://civelxu.com/2016/07/04/iOS%20使用%20Lame%20转码%20MP3%20的最正确姿势/)

### 致谢

> 对我有帮助的文章

* https://itony.me/365.html
* http://www.jianshu.com/p/57f38f075ba0




