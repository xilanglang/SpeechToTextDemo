//
//  ViewController.m
//  SpeechTOTextDemo
//
//  Created by miniu on 16/10/25.
//  Copyright © 2016年 mini. All rights reserved.
//

#import "ViewController.h"
#import <Speech/Speech.h>

@interface ViewController ()<SFSpeechRecognizerDelegate>

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIButton *microphoneButton;

@property (nonatomic, strong)SFSpeechRecognizer *speechRecognizer;
//处理语言识别请求，它给语言识别提供语音输入
@property (nonatomic, strong)SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
//告诉语言识别的结果，可以用它删除或者中断任务
@property (nonatomic, strong)SFSpeechRecognitionTask *recognitionTask;
//语音设备，负责提供语音输入
@property (nonatomic, strong)AVAudioEngine *audioEngine;

@end

@implementation ViewController
- (IBAction)microphoneTapped:(id)sender {
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
        [self.recognitionRequest endAudio];
        self.microphoneButton.userInteractionEnabled = NO;
        [self.microphoneButton setTitle:@"开始录制" forState:UIControlStateNormal];
    } else {
        [self startRecording];
        [self.microphoneButton setTitle:@"停止录制" forState:UIControlStateNormal];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _microphoneButton.userInteractionEnabled = NO;
    _textView.userInteractionEnabled = NO;
    //0.0获取权限
    //0.1在info.plist里面配置
    /*
     typedef NS_ENUM(NSInteger, SFSpeechRecognizerAuthorizationStatus) {
     SFSpeechRecognizerAuthorizationStatusNotDetermined,
     SFSpeechRecognizerAuthorizationStatusDenied,
     SFSpeechRecognizerAuthorizationStatusRestricted,
     SFSpeechRecognizerAuthorizationStatusAuthorized,
     };
     */
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                NSLog(@"NotDetermined");//未确定
                _microphoneButton.userInteractionEnabled = NO;
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                NSLog(@"Denied");
                _microphoneButton.userInteractionEnabled = NO;
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                NSLog(@"Restricted");//受限保密
                _microphoneButton.userInteractionEnabled = NO;
                break;
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                NSLog(@"Authorized");
                _microphoneButton.userInteractionEnabled = YES;
                break;
            default:
                break;
        }
    }];
}

- (void)startRecording {
    if (self.recognitionTask != nil) {
        [self.recognitionTask cancel];
        self.recognitionTask = nil;
    }
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *error;
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    if (error) {
        NSLog(@"%@", error.description);
        return;
    }
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    if (error) {
        NSLog(@"%@", error.description);
        return;
    }
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error) {
        NSLog(@"%@", error.description);
        return;
    }
    
    if (!self.audioEngine.inputNode) {
        NSLog(@"无输入节点");
        return;
    }
    if (!self.recognitionRequest) {
        NSLog(@"不能创建一个SFSpeechAudioBufferRecognitionRequest对象");
        return;
    }
    
    [self.audioEngine.inputNode installTapOnBus:0 bufferSize:1024 format:[self.audioEngine.inputNode outputFormatForBus:0] block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        if (buffer) {
            [self.recognitionRequest appendAudioPCMBuffer:buffer];
        }
    }];
    
    [self.audioEngine prepare];
    [self.audioEngine startAndReturnError:&error];
    if (error) {
        NSLog(@"%@", error.description);
        return;
    }
    self.textView.text = @"请说话，我正在听偶。。。";
    
    self.recognitionTask = [self.speechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        if (result != nil) {
            self.textView.text = result.bestTranscription.formattedString;
        }
        
        if (error != nil || result.isFinal) {
            [self.audioEngine stop];
            [self.audioEngine.inputNode removeTapOnBus:0];
            
            self.recognitionRequest = nil;
            self.recognitionTask = nil;
            
            self.microphoneButton.userInteractionEnabled = YES;
        }
    }];
}

#pragma mark - SFSpeechRecognizerDelegate
//需要保证当创建一个语音识别任务的时候语音识别功能是可用的，
//因此我们必须给ViewController添加一个代理方法。如果语音输入不可用或者改变了它的状态，
//那么 microphoneButton.enable属性就要被设置
- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    if (available) {
        self.microphoneButton.userInteractionEnabled = YES;
    } else {
        self.microphoneButton.userInteractionEnabled = NO;
    }
}

#pragma propertys
- (SFSpeechRecognizer *)speechRecognizer {
    if (!_speechRecognizer) {
        //1.创建本地化标识符
        NSLocale *local = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        //2.创建一个语音识别对象
        _speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:local];
        _speechRecognizer.delegate = self;
    }
    return _speechRecognizer;
}
- (SFSpeechAudioBufferRecognitionRequest *)recognitionRequest {
    if (!_recognitionRequest) {
        _recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        _recognitionRequest.shouldReportPartialResults = YES;
        
    }
    return  _recognitionRequest;
}
- (AVAudioEngine *)audioEngine {
    if (!_audioEngine) {
        _audioEngine = [[AVAudioEngine alloc] init];
    }
    return _audioEngine;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
