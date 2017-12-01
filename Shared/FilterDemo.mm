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

static const UInt8 kNumberOfPresets = 4;
static const NSInteger kDefaultFactoryPreset = 0;

typedef struct FactoryPresetParameters {
    AUValue keycenterValue;
    AUValue inversionValue;
    AUValue autoValue;
    AUValue midiValue;
    AUValue triadValue;
    AUValue intervalValues[72];
} FactoryPresetParameters;

static const FactoryPresetParameters presetParameters[kNumberOfPresets] =
{
    // Pop
    {
        0, //keycenter
        2, //inversion
        1, //autoharm
        1, //midi
        -1, //triad
        {4,7, 3,6, 3,7, 3,6, 3,8, 4,7, 3,6, 5,9, 4,8, 3,8, 4,9, 3,8, // major
         3,7, 3,6, 3,7, 4,9, 3,8, 4,9, 3,8, 5,8, 6,9, 5,8, 4,9, 4,8, // minor
         4,10, 3,8, 5,8, 6,9, 6,8, 4,9, 4,8, 3,7, 3,6, 3,7, 4,9, 3,8, //dom
        }
    },
    { // Jazz
        10, //keycenter
        2, //inversion
        1, //autoharm
        1, //midi
        -1, //triad
        {4,7, 3,6, 3,7, 3,6, 3,8, 4,7, 3,6, 5,9, 4,8, 3,8, 4,9, 3,8, // major
            3,7, 3,6, 3,7, 4,9, 3,8, 4,9, 3,8, 5,8, 6,9, 5,8, 4,9, 4,8, // minor
            4,7, 3,8, 5,8, 6,9, 6,8, 4,9, 4,8, 3,7, 3,6, 3,7, 4,9, 3,8, //dom
        }
    },
    { // Gospel
        7, //keycenter
        1, //inversion
        1, //autoharm
        1, //midi
        -1, //triad
        {4,7, 3,6, 3,7, 3,6, 3,8, 4,7, 3,6, 5,9, 4,8, 3,8, 4,9, 3,8, // major
            3,7, 3,6, 3,7, 4,9, 3,8, 4,9, 3,8, 5,8, 6,9, 5,8, 4,9, 4,8, // minor
            4,7, 3,8, 5,8, 6,9, 6,8, 4,9, 4,8, 3,7, 3,6, 3,7, 4,9, 3,8, //dom
        }
    },
    { // NeoSoul
        3, //keycenter
        2, //inversion
        1, //autoharm
        1, //midi
        -1, //triad
        {4,7, 3,6, 3,7, 3,6, 3,8, 4,7, 3,6, 5,9, 4,8, 3,8, 4,9, 3,8, // major
            3,7, 3,6, 3,7, 4,9, 3,8, 4,9, 3,8, 5,8, 6,9, 5,8, 4,9, 4,8, // minor
            4,7, 3,8, 5,8, 6,9, 6,8, 4,9, 4,8, 3,7, 3,6, 3,7, 4,9, 3,8, //dom
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
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];

	// Create a DSP kernel to handle the signal processing.
	_kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    
    AUParameter *keycenterIntervals[72];
    
    AUParameter *keycenterParam = [AUParameterTree createParameterWithIdentifier:@"keycenter" name:@"Key Center"
            address:HarmParamKeycenter
            min:0 max:47 unit:kAudioUnitParameterUnit_Indexed unitName:nil
            flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
            valueStrings:nil dependentParameters:nil];
    
    AUParameter *inversionParam = [AUParameterTree createParameterWithIdentifier:@"inversion" name:@"Inversion"
            address:HarmParamInversion
            min:0 max:2 unit:kAudioUnitParameterUnit_Indexed unitName:nil
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

    NSMutableArray *params = [NSMutableArray arrayWithCapacity:100];
    
    [params addObject:keycenterParam];
    [params addObject:inversionParam];
    [params addObject:autoParam];
    [params addObject:midiParam];
    [params addObject:triadParam];
    [params addObject:bypassParam];
    
    for (int k = 0; k < 72; k++)
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
    autoParam.value = 1;
    midiParam.value = 1;
    triadParam.value = -1;
    bypassParam.value = 0;
    
    _kernel.setParameter(HarmParamKeycenter, keycenterParam.value);
    _kernel.setParameter(HarmParamInversion, inversionParam.value);
    _kernel.setParameter(HarmParamAuto, autoParam.value);
    _kernel.setParameter(HarmParamMidi, midiParam.value);
    _kernel.setParameter(HarmParamTriad, triadParam.value);
    _kernel.setParameter(HarmParamBypass, bypassParam.value);
    
    for (int k = 0; k < 72; k++)
    {
        keycenterIntervals[k].value = _kernel.getParameter(HarmParamInterval + k);
    }
    
    // Create factory preset array.
	_currentFactoryPresetIndex = kDefaultFactoryPreset;
    _presets = @[NewAUPreset(0, @"Pop Triads"),NewAUPreset(0, @"Jazz Triads"),NewAUPreset(0, @"Gospel Triads"),NewAUPreset(0, @"NeoSoul")];
    
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

	self.maximumFramesToRender = 512;
    
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
		return NO;
	}
	
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        // Notify superclass that initialization was not successful
        self.renderResourcesAllocated = NO;
        
        return NO;
    }
	
	_inputBus.allocateRenderResources(self.maximumFramesToRender);
	
    printf("allocateRenderResources\n");
	_kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
	_kernel.reset();
	
	return YES;
}
	
- (void)deallocateRenderResources {
	_inputBus.deallocateRenderResources();
    
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (AUInternalRenderBlock)internalRenderBlock {
	/*
		Capture in locals to avoid ObjC member lookups. If "self" is captured in
        render, we're doing it wrong.
	*/
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
                
                AUParameter *keycenterParameter = [self.parameterTree valueForKey: @"keycenter"];
                AUParameter *inversionParameter = [self.parameterTree valueForKey: @"inversion"];
                AUParameter *autoParameter = [self.parameterTree valueForKey: @"auto"];
                AUParameter *midiParameter = [self.parameterTree valueForKey: @"midi"];
                AUParameter *triadParameter = [self.parameterTree valueForKey: @"triad"];

                keycenterParameter.value = presetParameters[factoryPreset.number].keycenterValue;
                inversionParameter.value = presetParameters[factoryPreset.number].inversionValue;
                autoParameter.value = presetParameters[factoryPreset.number].autoValue;
                midiParameter.value = presetParameters[factoryPreset.number].midiValue;
                triadParameter.value = presetParameters[factoryPreset.number].triadValue;
                
                for (int k = 0; k < 72; k++)
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
                //NSLog(@"currentPreset Factory: %ld, %@\n", (long)_currentFactoryPresetIndex, factoryPreset.name);
                
                break;
            }
        }
    } else if (nil != currentPreset.name) {
        // set custom preset as current
        _currentPreset = currentPreset;
        //NSLog(@"currentPreset Custom: %ld, %@\n", (long)_currentPreset.number, _currentPreset.name);
    } else {
        //NSLog(@"setCurrentPreset not set! - invalid AUAudioUnitPreset\n");
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
    return YES;
}

#pragma mark -

- (float) getCurrentNote {
    return _kernel.note_number;
}

- (float) getCurrentKeycenter {
    return _kernel.root_key;
}

@end
