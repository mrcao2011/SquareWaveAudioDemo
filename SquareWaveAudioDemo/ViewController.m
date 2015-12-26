//
//  ViewController.m
//  SquareWaveAudioDemo
//
//  Created by mr.cao on 15/12/26.
//  Copyright © 2015年 mr.cao. All rights reserved.
//

#import "ViewController.h"
#define kChannels   2
#define kOutputBus  0
#define kInputBus   1
#define AUDIO_SAMPLE_RATE 44100 //采样频率
#define _IOBASEFREQUENCY  613 //每位采样时间
#define BufferSize (int)(AUDIO_SAMPLE_RATE / _IOBASEFREQUENCY/2)*2 //每段波形上数据点数
@interface ViewController ()
{
    AURenderCallbackStruct		_inputProc;
    Float64						_hwSampleRate;//采样频率
    SignedByte                  _outHighHighBuffer[BufferSize];//波形为0，波峰
    SignedByte                  _outHighLowBuffer[BufferSize];//波形为1，半个波峰+半个波底
    SignedByte                  _outLowHighBuffer[BufferSize];//波形为1，半个波底+半个波峰
    SignedByte                  _outLowLowBuffer[BufferSize];//波形为0，波底
    BOOL                         bSend;//数据发送标志位，如果需要发送数据置为True
    NSData                       *_sendData;//发送数据
    NSUInteger                   _sendBufIndex;//数据发送的索引
}

@end

@implementation ViewController
@synthesize toneUnit;
@synthesize mAudioFormat;


static void CheckError(OSStatus error,const char *operaton){
    if (error==noErr) {
        return;
    }
    char errorString[20]={};
    *(UInt32 *)(errorString+1)=CFSwapInt32HostToBig(error);
    if (isprint(errorString[1])&&isprint(errorString[2])&&isprint(errorString[3])&&isprint(errorString[4])) {
        errorString[0]=errorString[5]='\'';
        errorString[6]='\0';
    }else{
        sprintf(errorString, "%d",(int)error);
    }
    fprintf(stderr, "Error:%s (%s)\n",operaton,errorString);
    exit(1);
}
OSStatus RenderTone(
                    void *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData)

{
    //NSLog(@"RenderTone:%ld,%d",ioData->mBuffers[0].mDataByteSize,(unsigned int)inNumberFrames);
    // Get the tone parameters out of the view controller
    ViewController* THIS = (__bridge ViewController *)inRefCon;
    
    //收到数据解析
    
     NSUInteger BYTES_LEN=ioData->mBuffers[0].mDataByteSize;//数据收到的大小
     NSData *readData=[[NSData alloc] initWithBytes:ioData->mBuffers[0].mData length:ioData->mBuffers[0].mDataByteSize];//收到的数据
    NSUInteger bufferShort[BYTES_LEN/2];
    SInt16 testByte[BYTES_LEN];
    [readData getBytes:&testByte length:BYTES_LEN];
    //将二进制数据转换为有符号的整数
    for(int i=0;i<BYTES_LEN/2;i++)
    {
        bufferShort[i]=((testByte[2*i] & 0xff) | ((testByte[2*i + 1] << 8) ) );
    }
        
        

    if(THIS->bSend)//数据发送
    {
        //将需要发送的数据转换为每位的数据数组，判断每位数据0或1从初始化的波形中取数据填充
        NSUInteger dataLen =THIS->_sendData.length;
        int length=inNumberFrames*2*kChannels/2;
        SignedByte bitcodedData[8*BufferSize*dataLen];
        SignedByte dataByte[dataLen];
        SignedByte sendBufferByte[length];
        [THIS->_sendData getBytes:&dataByte length:dataLen];
        
        BOOL tmpSin = true;
        BOOL tmpUp = true;
        int temLen = 0;
        memset(bitcodedData, 0, 8*BufferSize*dataLen);
        
        for (int i = 0; i < dataLen; i++) {
            for (int j = 0; j < 8; j++) {
                int bit = (dataByte[i]>>j) & (0x01 );//逆序二进制//data[i] & (0x80 >> j);// 顺序二进制数
                if (bit != 0) {
                    if (tmpSin) {
                        if (tmpUp) {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outHighLowBuffer[i];
                            }
                            
                        } else {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outLowHighBuffer[i];
                            }
                        }
                    } else {
                        if (tmpUp) {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outLowHighBuffer[i];
                            }
                            tmpUp = false;
                        } else {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outHighLowBuffer[i];
                            }
                            tmpUp = true;
                        }
                    }
                    tmpSin = true;
                } else {
                    if (tmpSin) {
                        if (tmpUp) {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outHighHighBuffer[i];
                            }
                            
                        } else {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outLowLowBuffer[i];
                            }
                        }
                    } else {
                        if (tmpUp) {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outLowLowBuffer[i];
                            }
                            tmpUp = false;
                        } else {
                            for(int i=0;i<BufferSize;i++)
                            {
                                bitcodedData[i+temLen]=THIS->_outHighHighBuffer[i];
                            }
                            tmpUp = true;
                        }
                    }
                    tmpSin = false;
                }
                temLen +=BufferSize;
            }
        }
        
        for (UInt32 i=0; i < inNumberFrames*2*kChannels/2; i++)
        {
            sendBufferByte[i]=bitcodedData[i+THIS->_sendBufIndex];
            
        }
        THIS->_sendBufIndex+=inNumberFrames*2*kChannels/2;
        // copy data into left channel
        memcpy(ioData->mBuffers[0].mData, sendBufferByte, ioData->mBuffers[0].mDataByteSize);//发送数据
        if(THIS->_sendBufIndex>=8*BufferSize*dataLen)
        {
            THIS->bSend=FALSE;
        }
        
    }
    else
    {
        SInt32 values[inNumberFrames*2*kChannels/2];
        for (int j=0; j<inNumberFrames*2*kChannels/2; j++) {
            values[j]=0;
        }
        // copy data into left channel
        memcpy(ioData->mBuffers[0].mData, values, ioData->mBuffers[0].mDataByteSize);
        
    }
    
    
    return noErr;
}


void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
    ViewController* THIS = (__bridge ViewController *)inClientData;
    if (inInterruptionState == kAudioSessionEndInterruption) {
        // make sure we are again the active session
        AudioSessionSetActive(true);
        AudioOutputUnitStart(THIS->toneUnit);
    }
    
    if (inInterruptionState == kAudioSessionBeginInterruption) {
        AudioOutputUnitStop(THIS->toneUnit);
    }
    
}
#pragma mark -Audio Session Property Listener

void propListener(	void *                  inClientData,
                  AudioSessionPropertyID	inID,
                  UInt32                  inDataSize,
                  const void *            inData)
{
    ViewController* THIS = (__bridge ViewController *)inClientData;
    
    if (inID == kAudioSessionProperty_AudioRouteChange)
    {
        
        // if there was a route change, we need to dispose the current rio unit and create a new one
        CheckError(AudioComponentInstanceDispose(THIS->toneUnit), "couldn't dispose remote i/o unit");
        //Obtain a RemoteIO unit instance---------------------
        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        acd.componentSubType = kAudioUnitSubType_RemoteIO;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
        AudioComponentInstanceNew(inputComponent, &THIS->toneUnit);
        
        //The Remote I/O unit, by default, has output enabled and input disabled
        //Enable input scope of input bus for recording.
        UInt32 enable = 1;
        UInt32 disable=0;
        AudioUnitSetProperty(THIS->toneUnit,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             kInputBus,
                             &enable,
                             sizeof(enable));
        CheckError(AudioUnitSetProperty(THIS->toneUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &THIS->_inputProc, sizeof(THIS->_inputProc)), "couldn't set remote i/o render callback");
        THIS->mAudioFormat.mSampleRate=AUDIO_SAMPLE_RATE;//采样率（立体声＝8000）
        THIS->mAudioFormat.mFormatID=kAudioFormatLinearPCM;//PCM格式
        THIS->mAudioFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        THIS->mAudioFormat.mFramesPerPacket    = 1;//每个数据包多少帧
        THIS->mAudioFormat.mChannelsPerFrame   = kChannels/2;//1单声道，2立体声
        THIS->mAudioFormat.mBitsPerChannel     = 16;//语音每采样点占用位数
        THIS->mAudioFormat.mBytesPerFrame      = THIS->mAudioFormat.mBitsPerChannel*THIS->mAudioFormat.mChannelsPerFrame/8;//每帧的bytes数
        THIS->mAudioFormat.mBytesPerPacket     = THIS->mAudioFormat.mBytesPerFrame*THIS->mAudioFormat.mFramesPerPacket;//每个数据包的bytes总数，每帧的bytes数＊每个数据包的帧数
        //NSLog(@"%ld",mAudioFormat.mBytesPerPacket);
        THIS->mAudioFormat.mReserved           = 0;
        
        CheckError(AudioUnitSetProperty(THIS->toneUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, disable, &THIS->mAudioFormat, sizeof(THIS->mAudioFormat)), "couldn't set the remote I/O unit's output client format");
        CheckError(AudioUnitSetProperty(THIS->toneUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, enable, &THIS->mAudioFormat, sizeof(THIS->mAudioFormat)), "couldn't set the remote I/O unit's input client format");
        
        CheckError(AudioUnitInitialize(THIS->toneUnit), "couldn't initialize the remote I/O unit");
        //---------------------
        
        
        UInt32 size = sizeof(THIS->_hwSampleRate);
        CheckError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &THIS->_hwSampleRate), "couldn't get new sample rate");
        
        CheckError(AudioOutputUnitStart(THIS->toneUnit), "couldn't start unit");
        
        // we need to rescale the sonogram view's color thresholds for different input
        CFStringRef newRoute;
        size = sizeof(CFStringRef);
        CheckError(AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute), "couldn't get new audio route");
        
    }
}






- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _hwSampleRate=AUDIO_SAMPLE_RATE;
    [self initHighLowBuffer];
    [self configAudio];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
// Initialize our remote i/o unit
- (void)configAudio
{
    // Set our tone rendering function on the unit
    _inputProc.inputProc = RenderTone;
    _inputProc.inputProcRefCon = (__bridge void *)(self);
    
    // Initialize and configure the audio session
    CheckError(AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, (__bridge void *)(self)), "couldn't initialize audio session");
    CheckError(AudioSessionSetActive(true), "couldn't set audio session active\n");
    
    UInt32 audioCategory = kAudioSessionCategory_PlayAndRecord;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(audioCategory), &audioCategory), "couldn't set audio category");
    CheckError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, (__bridge void *)(self)), "couldn't set property listener");
    Float32 preferredBufferSize = .005;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(preferredBufferSize), &preferredBufferSize), "couldn't set i/o buffer duration");
    
    UInt32 size = sizeof(_hwSampleRate);
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &_hwSampleRate), "couldn't get hw sample rate");
    //Obtain a RemoteIO unit instance
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
    AudioComponentInstanceNew(inputComponent, &toneUnit);
    
    //The Remote I/O unit, by default, has output enabled and input disabled
    //Enable input scope of input bus for recording.
    UInt32 enable = 1;
    UInt32 disable=0;
    AudioUnitSetProperty(toneUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         kInputBus,
                         &enable,
                         sizeof(enable));
    CheckError(AudioUnitSetProperty(toneUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &_inputProc, sizeof(_inputProc)), "couldn't set remote i/o render callback");
    mAudioFormat.mSampleRate=AUDIO_SAMPLE_RATE;//采样率（立体声＝8000）
    mAudioFormat.mFormatID=kAudioFormatLinearPCM;//PCM格式
    mAudioFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    mAudioFormat.mFramesPerPacket    = 1;//每个数据包多少帧
    mAudioFormat.mChannelsPerFrame   = kChannels/2;//1单声道，2立体声
    mAudioFormat.mBitsPerChannel     = 16;//语音每采样点占用位数
    mAudioFormat.mBytesPerFrame      = mAudioFormat.mBitsPerChannel*mAudioFormat.mChannelsPerFrame/8;//每帧的bytes数
    mAudioFormat.mBytesPerPacket     = mAudioFormat.mBytesPerFrame*mAudioFormat.mFramesPerPacket;//每个数据包的bytes总数，每帧的bytes数＊每个数据包的帧数
    mAudioFormat.mReserved           = 0;
    
    CheckError(AudioUnitSetProperty(toneUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, disable, &mAudioFormat, sizeof(mAudioFormat)), "couldn't set the remote I/O unit's output client format");
    CheckError(AudioUnitSetProperty(toneUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, enable, &mAudioFormat, sizeof(mAudioFormat)), "couldn't set the remote I/O unit's input client format");
    
    CheckError(AudioUnitInitialize(toneUnit), "couldn't initialize the remote I/O unit");
    //Obtain a RemoteIO unit instance
    UInt32 maxFPSt;
    size = sizeof(maxFPSt);
    CheckError(AudioUnitGetProperty(toneUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPSt, &size), "couldn't get the remote I/O unit's max frames per slice");
    //Create an audio file for recording
 
    
    CheckError(AudioOutputUnitStart(toneUnit), "couldn't start remote i/o unit");
    size = sizeof(mAudioFormat);
    CheckError(AudioUnitGetProperty(toneUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,1, &mAudioFormat,&size), "couldn't get the remote I/O unit's output client format");
}

-(void)initHighLowBuffer
{
    for (int i = 0; i < BufferSize/2; i++) {
        // shorts.+
        _outHighHighBuffer[i * 2] = 0xFF;
        _outHighHighBuffer[i * 2 + 1] = 0x5F;
        _outLowLowBuffer[i * 2] = 0x00;
        _outLowLowBuffer[i * 2 + 1] = 0x80;
        if (i < BufferSize / 4) {
            _outHighLowBuffer[i * 2] = 0xFF;
            _outHighLowBuffer[i * 2 + 1] = 0x5F;
            _outLowHighBuffer[i * 2] = 0x00;
            _outLowHighBuffer[i * 2 + 1] =0x80;
        } else {
            _outHighLowBuffer[i * 2] = 0x00;
            _outHighLowBuffer[i * 2+1] = 0x80;
            _outLowHighBuffer[i * 2] = 0xFF;
            _outLowHighBuffer[i * 2+1] = 0x5F;
        }
    }
}
@end
