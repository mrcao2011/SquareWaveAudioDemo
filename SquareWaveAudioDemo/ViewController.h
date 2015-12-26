//
//  ViewController.h
//  SquareWaveAudioDemo
//
//  Created by mr.cao on 15/12/26.
//  Copyright © 2015年 mr.cao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>
@interface ViewController : UIViewController
@property (nonatomic, assign)  AudioComponentInstance toneUnit;
@property (nonatomic, assign)  AudioStreamBasicDescription mAudioFormat;
@property (nonatomic, strong)  NSMutableData  *recevData;

@end

