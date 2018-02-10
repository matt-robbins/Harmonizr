/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	An AUAudioUnit subclass implementing a low-pass filter with resonance. Illustrates parameter management and rendering, including in-place processing and buffer management.
*/

#import "FilterDemo.h"
#import <AVFoundation/AVFoundation.h>
#import "FilterDSPKernel.hpp"
#import "BufferedAudioBus.hpp"

#include <dispatch/dispatch.h>

#pragma mark AUv3FilterDemo (Presets)

static const UInt8 kNumberOfPresets = 3;
static const NSInteger kDefaultFactoryPreset = 0;

typedef struct FactoryPresetParameters {
    AUValue keycenterValue;
    AUValue inversionValue;
    AUValue nvoicesValue;
    AUValue autoValue;
    AUValue midiValue;
    AUValue triadValue;
    AUValue intervalValues[144];
} FactoryPresetParameters;

static const FactoryPresetParameters presetParameters[kNumberOfPresets] =
{
    
    // Chords
    {
        0, //keycenter
        2, //inversion
        4,
        1, //autoharm
        1, //midi
        -1, //triad
        {0,4,7,12, -1,3,6,11, 2,5,10,14, 1,4,9,13, 0,3,8,12, -1,2,7,11, 1,6,10,13, 0,5,9,12, -1,4,8,11, 0,3,7,10, 2,6,9,14, 1,5,8,13, // major
         0,3,7,12, -1,2,6,11, 1,5,10,13, 0,4,9,12, -1,3,8,11, -1,2,7,10, 1,6,9,13, 0,5,8,12, 0,4,7,11, 0,3,6,10, 0,5,9,14, 1,4,8,13, // minor
         0,4,10,12, -1,3,9,11, -2,2,8,10, 1,4,7,9, 0,3,6,8, 2,5,7,11, 1,4,6,10, 0,3,5,9, -1,2,4,8, 1,3,7,10, 0,2,6,9, -1,1,5,8, //dom
        }
    },
    // diatonic
    {
        0, //keycenter
        2, //inversion
        4,
        1, //autoharm
        1, //midi
        -1, //triad
        {0,4,7,12, -1,3,6,11, 0,5,10,12, 1,4,9,13, 0,3,8,12, 0,2,7,11, 1,6,10,13, 0,5,9,12, -1,4,8,11, 0,3,7,12, 1,2,6,13, 0,1,5,12, // major
            0,3,7,12, -1,2,6,11, 0,5,10,12, 0,4,9,12, -1,3,8,11, -2,2,7,10, 1,6,9,13, 0,5,8,12, -1,4,7,11, 0,3,6,10, 2,5,9,14, 1,4,8,13, // minor
            0,4,7,10, -1,3,9,11, -2,2,8,10, 1,4,7,9, 0,3,6,8, 2,5,7,11, 1,4,6,10, 0,3,5,9, -1,2,4,8, 1,3,7,10, 0,2,6,9, -1,1,5,8, //dom
        }
    },
    { // Chromatic
        0, //keycenter
        2, //inversion
        4,
        1, //autoharm
        1, //midi
        -1, //triad
        {0,4,7,9, 0,3,6,8, 0,3,6,9, 0,3,6,9, 0,3,5,8, 0,3,6,9, 0,3,6,9, 0,2,5,9, 0,3,6,9, 0,3,7,10, 0,4,7,10, 0,3,6,9, // major
            0,3,7,9, 0,3,6,8, 0,3,6,9, 0,4,6,9, 0,3,5,8, 0,3,6,9, 0,3,6,9, 0,2,5,8, 0,3,6,9, 0,3,6,10, 0,4,7,10, 0,3,6,9, // minor
            0,4,7,10, 0,3,6,9, 0,3,6,9, 0,3,6,9, 0,3,6,8, 0,3,6,9, 0,3,5,9, 0,3,5,9, 0,3,6,9, 0,3,6,9, 0,2,6,9, 0,3,6,9 //dom
        }
    },
};

static AUAudioUnitPreset* NewAUPreset(NSInteger number, NSString *name)
{
    AUAudioUnitPreset *aPreset = [AUAudioUnitPreset new];
    aPreset.number = number;
    aPreset.name = name;
    return aPreset;
}

#pragma mark - AUv3FilterDemo : AUAudioUnit

@interface AUv3Harmonizer ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;

@end

@implementation AUv3Harmonizer {
	// C++ members need to be ivars; they would be copied on access if they were properties.
    FilterDSPKernel  _kernel;
    BufferedInputBus _inputBus;
    
    AUAudioUnitPreset   *_currentPreset;
    NSInteger           _currentFactoryPresetIndex;
    NSArray<AUAudioUnitPreset *> *_presets;
}
@synthesize parameterTree = _parameterTree;
@synthesize factoryPresets = _presets;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    if (self == nil) { return nil; }
	
	// Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:1];

	// Create a DSP kernel to handle the signal processing.
	_kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    
    AUParameter *keycenterIntervals[144];
    
    AUParameter *keycenterParam = [AUParameterTree createParameterWithIdentifier:@"keycenter" name:@"Key Center"
            address:HarmParamKeycenter
            min:0 max:47 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];
    
    AUParameter *inversionParam = [AUParameterTree createParameterWithIdentifier:@"inversion" name:@"Inversion"
            address:HarmParamInversion
            min:0 max:3 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];
    
    AUParameter *nvoicesParam = [AUParameterTree createParameterWithIdentifier:@"nvoices" name:@"Voices"
            address:HarmParamNvoices
            min:1 max:4 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];

    AUParameter *autoParam = [AUParameterTree createParameterWithIdentifier:@"auto" name:@"Auto"
             address:HarmParamAuto
             min:0 max:1 unit:kAudioUnitParameterUnit_Indexed unitName:nil
             flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
             valueStrings:nil dependentParameters:nil];
    
    AUParameter *midiParam = [AUParameterTree createParameterWithIdentifier:@"midi" name:@"Midi"
            address:HarmParamMidi
            min:0 max:1 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];
    
    AUParameter *bypassParam = [AUParameterTree createParameterWithIdentifier:@"bypass" name:@"Bypass"
            address:HarmParamBypass
            min:0 max:1 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];
    
    AUParameter *triadParam = [AUParameterTree createParameterWithIdentifier:@"triad" name:@"Triad"
            address:HarmParamTriad
         min:-1 max:30 unit:kAudioUnitParameterUnit_Indexed unitName:nil
         flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
         valueStrings:nil dependentParameters:nil];
    
    AUParameter *hgainParam = [AUParameterTree createParameterWithIdentifier:@"h_gain" name:@"Harmony Gain"
         address:HarmParamHgain
             min:0 max:1 unit:kAudioUnitParameterUnit_Percent unitName:nil
           flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];
    
    AUParameter *vgainParam = [AUParameterTree createParameterWithIdentifier:@"v_gain" name:@"Voice Gain"
                                                                     address:HarmParamVgain
                                                                         min:0 max:1 unit:kAudioUnitParameterUnit_Percent unitName:nil
                                                                       flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                                valueStrings:nil dependentParameters:nil];
    
    AUParameter *speedParam = [AUParameterTree createParameterWithIdentifier:@"speed" name:@"Speed"
                                                                     address:HarmParamSpeed
                                                                         min:0 max:1 unit:kAudioUnitParameterUnit_Percent unitName:nil
                                                                       flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                                valueStrings:nil dependentParameters:nil];

    NSMutableArray *params = [NSMutableArray arrayWithCapacity:100];
    
    [params addObject:keycenterParam];
    [params addObject:inversionParam];
    [params addObject:nvoicesParam];
    [params addObject:autoParam];
    [params addObject:midiParam];
    [params addObject:triadParam];
    [params addObject:bypassParam];
    [params addObject:hgainParam];
    [params addObject:vgainParam];
    [params addObject:speedParam];
        
    for (int k = 0; k < 144; k++)
    {
        NSString *identifier = [NSString stringWithFormat:@"interval_%d", k];
        NSString *name = [NSString stringWithFormat:@"Interval %d", k];
        keycenterIntervals[k] = [AUParameterTree createParameterWithIdentifier:identifier name:name
            address:HarmParamInterval+k
            min:1 max:13 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
                                                                  valueStrings:nil dependentParameters:nil];
        
        [params addObject: keycenterIntervals[k]];
    }
    
	// Initialize default parameter values.
    keycenterParam.value = 5;
    inversionParam.value = 2;
    nvoicesParam.value = 4;
    autoParam.value = 1;
    midiParam.value = 1;
    triadParam.value = -1;
    bypassParam.value = 0;
    vgainParam.value = 1;
    hgainParam.value = 1;
    speedParam.value = 1;
    
    _kernel.setParameter(HarmParamKeycenter, keycenterParam.value);
    _kernel.setParameter(HarmParamInversion, inversionParam.value);
    _kernel.setParameter(HarmParamNvoices, nvoicesParam.value);
    _kernel.setParameter(HarmParamAuto, autoParam.value);
    _kernel.setParameter(HarmParamMidi, midiParam.value);
    _kernel.setParameter(HarmParamTriad, triadParam.value);
    _kernel.setParameter(HarmParamBypass, bypassParam.value);
    
//    for (int k = 0; k < 144; k++)
//    {
//        keycenterIntervals[k].value = _kernel.getParameter(HarmParamInterval + k);
//    }
    
    // Create factory preset array.
	_currentFactoryPresetIndex = kDefaultFactoryPreset;
    _presets = @[NewAUPreset(0, @"Chords"),NewAUPreset(1, @"Diatonic"),NewAUPreset(2, @"Chromatic")];
    
	// Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:params];

	// Create the input and output busses.
	_inputBus.init(defaultFormat, 8);
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];

	// Create the input and output bus arrays.
	_inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus.bus]];
	_outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];

	// Make a local pointer to the kernel to avoid capturing self.
	__block FilterDSPKernel *filterKernel = &_kernel;

	// implementorValueObserver is called when a parameter changes value.
	_parameterTree.implementorValueObserver = ^(AUParameter *param, AUValue value) {
        filterKernel->setParameter(param.address, value);
	};
	
	// implementorValueProvider is called when the value needs to be refreshed.
	_parameterTree.implementorValueProvider = ^(AUParameter *param) {
		return filterKernel->getParameter(param.address);
	};
	
	// A function to provide string representations of parameter values.
	_parameterTree.implementorStringFromValueCallback = ^(AUParameter *param, const AUValue *__nullable valuePtr) {
		//AUValue value = valuePtr == nil ? param.value : *valuePtr;
	
		switch (param.address) {
			default:
				return @"?";
		}
	};

	self.maximumFramesToRender = 4096;
    
    // set default preset as current
    self.currentPreset = _presets.firstObject;

	return self;
}

-(void)dealloc {
    _presets = nil;
}

#pragma mark - AUAudioUnit (Overrides)

- (AUAudioUnitBusArray *)inputBusses {
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses {
    return _outputBusArray;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError {

    if (![super allocateRenderResourcesAndReturnError:outError]) {
        NSLog(@"allocateRenderResources, super failed...\n");
		return NO;
	}
    
    int maxchannels = self.outputBus.format.channelCount;
    if (_inputBus.bus.format.channelCount > maxchannels)
        maxchannels = _inputBus.bus.format.channelCount;
	
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        // Notify superclass that initialization was not successful
        self.renderResourcesAllocated = NO;

        NSLog(@"** can't allocate render resources, mismatched channel counts!\n");

        return NO;
    }
	
	_inputBus.allocateRenderResources(self.maximumFramesToRender);
	
	_kernel.init(maxchannels, self.outputBus.format.sampleRate);
	_kernel.reset();
	
	return YES;
}
	
- (void)deallocateRenderResources {
	_inputBus.deallocateRenderResources();
    _kernel.fini();
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
	/*
		Capture in locals to avoid ObjC member lookups. If "self" is captured in
        render, we're doing it wrong.
	*/
    NSLog(@"getting render block!");
    // Specify captured objects are mutable.
	__block FilterDSPKernel *state = &_kernel;
	__block BufferedInputBus *input = &_inputBus;
    
    return ^AUAudioUnitStatus(
			 AudioUnitRenderActionFlags *actionFlags,
			 const AudioTimeStamp       *timestamp,
			 AVAudioFrameCount           frameCount,
			 NSInteger                   outputBusNumber,
			 AudioBufferList            *outputData,
			 const AURenderEvent        *realtimeEventListHead,
			 AURenderPullInputBlock      pullInputBlock) {
		AudioUnitRenderActionFlags pullFlags = 0;

		AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
		
        if (err != 0) { return err; }
		
		AudioBufferList *inAudioBufferList = input->mutableAudioBufferList;
		
        /*
         Important:
             If the caller passed non-null output pointers (outputData->mBuffers[x].mData), use those.
             
             If the caller passed null output buffer pointers, process in memory owned by the Audio Unit
             and modify the (outputData->mBuffers[x].mData) pointers to point to this owned memory.
             The Audio Unit is responsible for preserving the validity of this memory until the next call to render,
             or deallocateRenderResources is called.
             
             If your algorithm cannot process in-place, you will need to preallocate an output buffer
             and use it here.
         
             See the description of the canProcessInPlace property.
         */
        
        // If passed null output buffer pointers, process in-place in the input buffer.
		AudioBufferList *outAudioBufferList = outputData;
		if (outAudioBufferList->mBuffers[0].mData == nullptr) {
			for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
				outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
			}
		}
		
		state->setBuffers(inAudioBufferList, outAudioBufferList);
		state->processWithEvents(timestamp, frameCount, realtimeEventListHead);
        
		return noErr;
	};
}

#pragma mark- AUAudioUnit (Optional Properties)

- (AUAudioUnitPreset *)currentPreset
{
    if (_currentPreset.number >= 0) {
        NSLog(@"Returning Current Factory Preset: %ld\n", (long)_currentFactoryPresetIndex);
        return [_presets objectAtIndex:_currentFactoryPresetIndex];
    } else {
        NSLog(@"Returning Current Custom Preset: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
        return _currentPreset;
    }
}

- (void)setCurrentPreset:(AUAudioUnitPreset *)currentPreset
{
    if (nil == currentPreset) { NSLog(@"nil passed to setCurrentPreset!"); return; }
    
    if (currentPreset.number >= 0) {
        // factory preset
        for (AUAudioUnitPreset *factoryPreset in _presets) {
            if (currentPreset.number == factoryPreset.number) {
                
//                AUParameter *keycenterParameter = [self.parameterTree valueForKey: @"keycenter"];
//                AUParameter *inversionParameter = [self.parameterTree valueForKey: @"inversion"];
//                AUParameter *autoParameter = [self.parameterTree valueForKey: @"auto"];
//                AUParameter *midiParameter = [self.parameterTree valueForKey: @"midi"];
//                AUParameter *triadParameter = [self.parameterTree valueForKey: @"triad"];

                //keycenterParameter.value = presetParameters[factoryPreset.number].keycenterValue;
                //inversionParameter.value = presetParameters[factoryPreset.number].inversionValue;
                //autoParameter.value = presetParameters[factoryPreset.number].autoValue;
                //midiParameter.value = presetParameters[factoryPreset.number].midiValue;
                //triadParameter.value = presetParameters[factoryPreset.number].triadValue;
                
                for (int k = 0; k < 144; k++)
                {
                    AUParameter * p = [self.parameterTree valueForKey: [NSString stringWithFormat:@"interval_%d", k]];
                    if (p)
                    {
                        p.value = presetParameters[factoryPreset.number].intervalValues[k];
                    }
                    p = nil;
                }
//                
                // set factory preset as current
                _currentPreset = currentPreset;
                _currentFactoryPresetIndex = factoryPreset.number;
                NSLog(@"currentPreset Factory: %ld, %@\n", (long)_currentFactoryPresetIndex, factoryPreset.name);
                
                break;
            }
        }
    } else if (nil != currentPreset.name) {
        // set custom preset as current
        _currentPreset = currentPreset;
        NSLog(@"currentPreset Custom: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
    } else {
        NSLog(@"setCurrentPreset not set! - invalid AUAudioUnitPreset\n");
    }
}

// Expresses whether an audio unit can process in place.
// In-place processing is the ability for an audio unit to transform an input signal to an
// output signal in-place in the input buffer, without requiring a separate output buffer.
// A host can express its desire to process in place by using null mData pointers in the output
// buffer list. The audio unit may process in-place in the input buffers.
// See the discussion of renderBlock.
// Partially bridged to the v2 property kAudioUnitProperty_InPlaceProcessing, the v3 property is not settable.
- (BOOL)canProcessInPlace {
    return NO;
}

#pragma mark -

- (float) getCurrentNote {
    return _kernel.note_number;
}

- (float) getCurrentKeycenter {
    return _kernel.root_key;
}

@end
