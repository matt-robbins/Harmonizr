/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	An AUAudioUnit subclass implementing a low-pass filter with resonance. Illustrates parameter management and rendering, including in-place processing and buffer management.
*/

#import "Harmonizer.h"
#import <AVFoundation/AVFoundation.h>
#import "../harmonizr-dsp/HarmonizerDSPKernel.hpp"
#import "BufferedAudioBus.hpp"

#include <dispatch/dispatch.h>

#pragma mark AUv3Harmonizer (Presets)

static const UInt8 kNumberOfPresets = 9;
static const NSInteger kDefaultFactoryPreset = 0;

typedef struct FactoryPresetParameters {
    AUValue keycenterValue;
    AUValue inversionValue;
    AUValue nvoicesValue;
    AUValue autoValue;
    AUValue autoStrengthValue;
    AUValue midiValue;
    AUValue triadValue;
    AUValue intervalValues[144];
} FactoryPresetParameters;

enum LoopMode {
    stopped = LoopStopped,
    rec = LoopRec,
    play = LoopPlay,
    playrec = LoopPlayRec,
    paused = LoopPause
};

static const FactoryPresetParameters presetParameters[kNumberOfPresets] =
{
    // Chords
    {
        0, //keycenter
        2, //inversion
        4,
        0, //autotune
        0,
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
        0, //autotune
        0,
        1, //midi
        -1, //triad
        {0,4,7,12, -1,3,6,11, 0,5,10,12, 1,4,9,13, 0,3,8,12, 0,2,7,11, 1,6,10,13, 0,5,9,12, -1,4,8,11, 0,3,7,12, 1,2,6,13, 0,1,5,12, // major
            0,3,7,12, -1,2,6,11, 0,5,10,12, 0,4,9,12, -1,3,8,11, -2,2,7,10, 1,6,9,13, 0,5,8,12, -1,4,7,11, 0,3,6,10, 2,5,9,14, 1,4,8,13, // minor
            0,4,7,10, -1,3,9,11, -2,2,8,10, 1,4,7,9, 0,3,6,8, 2,5,7,11, 1,4,6,10, 0,3,5,9, -1,2,4,8, 1,3,7,10, 0,2,6,9, -1,1,5,8, //dom
        }
    },
    // chromatic
    {
        0, //keycenter
        2, //inversion
        4,
        0, //autotune
        0,
        1, //midi
        -1, //triad
        {0,4,7,12, 0,3,6,12, 0,3,7,12, 0,3,9,12, 0,3,8,12, 0,4,7,12, 0,3,9,12, 0,5,9,12, 0,4,8,12, 0,5,8,12, 0,4,7,12, 0,3,6,12, // major
            0,3,7,12, 0,4,7,12, 0,3,9,12, 0,4,9,12, 0,3,8,12, 0,3,7,12, 0,6,9,12, 0,4,7,12, 0,4,7,12, 0,3,6,12, 0,5,9,12, 0,3,7,12, // minor
            0,4,7,12, 0,3,9,12, 0,2,8,12, 0,4,7,12, 0,3,6,12, 0,5,7,12, 0,4,6,12, 0,3,5,12, 0,2,4,12, 0,3,7,12, 0,2,6,12, 0,1,5,12, //dom
        }
    },
    { // Barbershop
        0, //keycenter
        1, //inversion
        4,
        0, //autotune
        0,
        1, //midi
        -1, //triad
        {0,4,7,12, 0,3,5,9, 0,3,5,9, 0,3,6,9, 0,3,8,12, 0,2,6,9, 0,3,5,9, 0,5,9,12, 0,3,6,9, 0,3,5,9, 0,3,6,9, 0,3,6,8, // major
            0,3,7,12, 0,4,7,10, 0,3,5,9, 0,4,9,12, 0,3,6,8, 0,3,7,9, 0,3,6,8, 0,5,8,12, 0,4,7,10, 0,3,6,10, 0,4,7,10, 0,3,6,8, // minor
            0,4,7,10, 0,3,6,9, 0,3,5,9, 0,3,6,9, 0,3,6,8, 0,2,6,9, 0,3,5,9, 0,3,5,9, 0,2,4,8, 0,3,6,9, 0,2,6,9, 0,4,7,10 //dom
        }
    },
    // JustMidi
    {
        0, //keycenter
        2, //inversion
        1,
        0, //autotune
        0,
        1, //midi
        -1, //triad
        {0,4,7,12, 0,3,6,11, 0,5,10,14, 0,4,9,13, 0,3,8,12, 0,2,7,11, 0,6,10,13, 0,5,9,12, 0,4,8,11, 0,3,7,10, 0,6,9,14, 0,5,8,13, // major
            0,3,7,12, 0,2,6,11, 0,5,10,13, 0,4,9,12, 0,3,8,11, 0,2,7,10, 0,6,9,13, 0,5,8,12, 0,4,7,11, 0,3,6,10, 0,5,9,14, 0,4,8,13, // minor
            0,4,10,12, 0,3,9,11, 0,2,8,10, 0,4,7,9, 0,3,6,8, 0,5,7,11, 0,4,6,10, 0,3,5,9, 0,2,4,8, 0,3,7,10, 0,2,6,9, 0,1,5,8, //dom
        }
    },
    { // Bohemian?
        0, //keycenter
        3, //inversion
        4,
        0, //autotune
        0,
        1, //midi
        -1, //triad
        {0,4,7,9, 0,3,6,8, 0,3,7,10, 0,3,6,9, 0,3,5,8, 0,4,7,9, 0,3,6,9, 0,2,5,9, 0,3,6,9, 0,3,5,8, 0,2,6,9, 0,1,5,8, // major
            0,3,7,10, 0,3,6,8, 0,3,6,9, 0,4,7,9, 0,3,5,8, 0,3,6,9, 0,3,6,9, 0,3,5,8, 0,3,6,9, 0,3,6,10, 0,4,7,10, 0,3,6,9, // minor
            0,4,7,10, 0,3,6,9, 0,3,5,8, 0,3,6,9, 0,3,6,8, 0,2,5,9, 0,3,5,9, 0,3,5,9, 0,2,6,9, 0,1,5,8, 0,2,6,9, 0,3,6,9 //dom
        }
    },
    { // Bass!
        0, //keycenter
        1, //inversion
        1,
        0, //autotune
        1,
        1, //midi
        1, //triad
        {-12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, // "major"
            -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, // "minor"
            -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, -12,-12,-12,-12, // "dom"
        }
    },
    { // 4ths
        0, //keycenter
        2, //inversion
        3,
        0, //autotune
        1,
        1, //midi
        1, //triad
        {0,-5,7,12, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, // "major"
            0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, // "minor"
            0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, // "dom"
        }
    },
    { // Modes
        0, //keycenter
        3, //inversion
        4,
        0, //autotune
        0,
        1, //midi
        -1, //triad
        {0,4,7,11, 0,3,6,10, 0,3,7,10, 0,3,6,9, 0,3,7,10, 0,4,7,11, 0,3,6,10, 0,4,7,10, 0,4,8,11, 0,3,7,10, 0,4,7,11, 0,3,6,10, // major
            0,3,7,11, 0,3,7,10, 0,3,7,10, 0,4,8,11, 0,4,7,10, 0,4,7,10, 0,4,7,10, 0,4,7,10, 0,4,7,11, 0,3,6,10, 0,3,6,10, 0,3,6,10, // minor
            0,4,7,10, 0,3,7,10, 0,3,7,10, 0,3,6,10, 0,3,6,10, 0,4,7,11, 0,3,7,10, 0,3,7,10, 0,3,7,10, 0,3,7,10, 0,4,7,11, 0,4,7,10 //dom
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

#pragma mark - AUv3Harmonizer : AUAudioUnit

@interface AUv3Harmonizer ()

@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;


@end

@implementation AUv3Harmonizer {
	// C++ members need to be ivars; they would be copied on access if they were properties.
    HarmonizerDSPKernel  _kernel;
    BufferedInputBus _inputBus;
    dispatch_semaphore_t _sem;
    
    bool embedded;
    
    AUAudioUnitPreset   *_currentPreset;
    NSInteger           _currentFactoryPresetIndex;
    NSMutableArray<NSNumber *> *keysDown;
    NSArray<AUAudioUnitPreset *> *_presets;
}
@synthesize parameterTree = _parameterTree;
@synthesize factoryPresets = _presets;

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError {
    self = [super initWithComponentDescription:componentDescription options:options error:outError];
    if (self == nil) { return nil; }
	
    //AVAudioSession.sharedInstance().sampleRate
    
	// Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:[AVAudioSession sharedInstance].sampleRate channels:2];

	// Create a DSP kernel to handle the signal processing.
    _kernel.init(defaultFormat.channelCount, defaultFormat.channelCount, defaultFormat.sampleRate);
    
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

    AUParameter *autoParam = [AUParameterTree createParameterWithIdentifier:@"auto" name:@"Autotune"
        address:HarmParamAuto
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *autoStrengthParam = [AUParameterTree createParameterWithIdentifier:@"auto_strength" name:@"Autotune Strength"
        address:HarmParamAutoStrength
        min:0 max:1 unit:kAudioUnitParameterUnit_Generic unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *midiParam = [AUParameterTree createParameterWithIdentifier:@"midi" name:@"Midi"
        address:HarmParamMidi
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *midiLinkParam = [AUParameterTree createParameterWithIdentifier:@"midi_link" name:@"Midi Link"
        address:HarmParamMidiLink
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];

    AUParameter *midiLegatoParam = [AUParameterTree createParameterWithIdentifier:@"midi_legato" name:@"Midi Legato"
        address:HarmParamMidiLegato
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *keycenterCCParam = [AUParameterTree createParameterWithIdentifier:@"keycenter_cc" name:@"Keycenter CC"
        address:HarmParamMidiKeyCC
        min:0 max:127 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *keycenterCcOffsetParam = [AUParameterTree createParameterWithIdentifier:@"keycenter_cc_offset" name:@"Keycenter CC Value Offset"
        address:HarmParamMidiKeyCcOffset
        min:0 max:127 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *keyqualityCCParam = [AUParameterTree createParameterWithIdentifier:@"keyquality_cc" name:@"Key Quality (Maj/Mi/7) CC"
        address:HarmParamMidiQualCC
        min:0 max:127 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *keyqualityCcOffsetParam = [AUParameterTree createParameterWithIdentifier:@"keyquality_cc_offset" name:@"Key quality CC Value Offset"
        address:HarmParamMidiQualCcOffset
        min:0 max:127 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *nvoicesCCParam = [AUParameterTree createParameterWithIdentifier:@"nvoices_cc" name:@"Voice Count CC"
        address:HarmParamMidiNvoiceCC
        min:0 max:127 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *nvoicesCcRangeParam = [AUParameterTree createParameterWithIdentifier:@"nvoices_cc_range" name:@"Voice Count CC Mode"
        address:HarmParamMidiNvoiceCcRange
        min:0 max:1 unit:kAudioUnitParameterUnit_Indexed unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:@[@"Normalized",@"Literal"] dependentParameters:nil];
    
    AUParameter *inversionCCParam = [AUParameterTree createParameterWithIdentifier:@"inversion_cc" name:@"Inversion CC"
        address:HarmParamMidiInvCC
        min:0 max:127 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *inversionCcRangeParam = [AUParameterTree createParameterWithIdentifier:@"inversion_cc_range" name:@"Inversion CC Mode"
        address:HarmParamMidiInvCcRange
        min:0 max:1 unit:kAudioUnitParameterUnit_MIDIController unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:@[@"Normalized",@"Literal"] dependentParameters:nil];
    
    AUParameter *midiPCParam = [AUParameterTree createParameterWithIdentifier:@"midi_rx_pc" name:@"Recieve MIDI Program Change"
        address:HarmParamMidiPC
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *midiMelOutParam = [AUParameterTree createParameterWithIdentifier:@"midi_tx_mel" name:@"Transmit MIDI melody"
        address:HarmParamMidiMelOut
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *midiHarmOutParam = [AUParameterTree createParameterWithIdentifier:@"midi_tx_harm" name:@"Transmit MIDI harmony"
        address:HarmParamMidiHarmOut
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *bypassParam = [AUParameterTree createParameterWithIdentifier:@"bypass" name:@"Bypass"
        address:HarmParamBypass
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *triadParam = [AUParameterTree createParameterWithIdentifier:@"triad" name:@"Triad"
        address:HarmParamTriad
        min:-1 max:30 unit:kAudioUnitParameterUnit_Indexed unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *hgainParam = [AUParameterTree createParameterWithIdentifier:@"h_gain" name:@"Harmony Gain"
        address:HarmParamHgain
        min:0 max:1 unit:kAudioUnitParameterUnit_LinearGain unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *vgainParam = [AUParameterTree createParameterWithIdentifier:@"v_gain" name:@"Voice Gain"
        address:HarmParamVgain
        min:0 max:2 unit:kAudioUnitParameterUnit_LinearGain unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *dryMixParam = [AUParameterTree createParameterWithIdentifier:@"dry_mix" name:@"Dry Mix"
        address:HarmParamDryMix
        min:0 max:1 unit:kAudioUnitParameterUnit_LinearGain unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *speedParam = [AUParameterTree createParameterWithIdentifier:@"speed" name:@"Speed"
        address:HarmParamSpeed
        min:0 max:1 unit:kAudioUnitParameterUnit_Generic unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *tuningParam = [AUParameterTree createParameterWithIdentifier:@"tuning" name:@"Tuning"
        address:HarmParamTuning
        min:400 max:500 unit:kAudioUnitParameterUnit_Hertz unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];

    AUParameter *threshParam = [AUParameterTree createParameterWithIdentifier:@"threshold" name:@"Threshold"
        address:HarmParamThreshold
        min:0 max:1 unit:kAudioUnitParameterUnit_Generic unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *stereoParam = [AUParameterTree createParameterWithIdentifier:@"stereo_mode" name:@"Stereo Mode"
        address:HarmParamStereo
        min:0 max:2 unit:kAudioUnitParameterUnit_Indexed unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:@[@"Normal",@"Mono",@"Split"] dependentParameters:nil];
    
    AUParameter *synthParam = [AUParameterTree createParameterWithIdentifier:@"synth_enable" name:@"VowelMatch Synth"
        address:HarmParamSynth
        min:0 max:1 unit:kAudioUnitParameterUnit_Boolean unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *vibParam = [AUParameterTree createParameterWithIdentifier:@"vibrato" name:@"Vibrato Intensity"
        address:HarmParamVibrato
        min:0 max:1 unit:kAudioUnitParameterUnit_Generic unitName:nil
        flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
        valueStrings:nil dependentParameters:nil];
    
    AUParameter *loopParam = [AUParameterTree createParameterWithIdentifier:@"loop_mode" name:@"Looping Mode"
    address:HarmParamLoop
    min:0 max:1 unit:kAudioUnitParameterUnit_Indexed unitName:nil
    flags: kAudioUnitParameterFlag_IsReadable | kAudioUnitParameterFlag_IsWritable
    valueStrings:@[@"Stop",@"Play",@"play/Rec"] dependentParameters:nil];
    
    NSMutableArray *params = [NSMutableArray arrayWithCapacity:100];
    
    [params addObject:keycenterParam];
    [params addObject:inversionParam];
    [params addObject:nvoicesParam];
    [params addObject:autoParam];
    [params addObject:autoStrengthParam];
    [params addObject:midiParam];
    [params addObject:midiLinkParam];
    [params addObject:midiLegatoParam];
    [params addObject:keycenterCCParam];
    [params addObject:keycenterCcOffsetParam];
    [params addObject:keyqualityCCParam];
    [params addObject:keyqualityCcOffsetParam];
    [params addObject:inversionCCParam];
    [params addObject:inversionCcRangeParam];
    [params addObject:nvoicesCCParam];
    [params addObject:nvoicesCcRangeParam];
    [params addObject:midiPCParam];
    [params addObject:midiMelOutParam];
    [params addObject:midiHarmOutParam];
    [params addObject:triadParam];
    [params addObject:bypassParam];
    [params addObject:hgainParam];
    [params addObject:vgainParam];
    [params addObject:dryMixParam];
    [params addObject:speedParam];
    [params addObject:tuningParam];
    [params addObject:threshParam];
    [params addObject:stereoParam];
    [params addObject:synthParam];
    [params addObject:vibParam];
    [params addObject:loopParam];
            
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
    
//    AUParameterGroup *intervals = [AUParameterTree createGroupWithIdentifier:@"intervals" name:@"Auto-Harmony" children:iparams];
//
//    [params addObject:intervals];
    
	// Initialize default parameter values.
    keycenterParam.value = 5;
    inversionParam.value = 2;
    nvoicesParam.value = 4;
    autoParam.value = 1;
    autoStrengthParam.value = 0.5;
    midiParam.value = 1;
    midiLinkParam.value = 1;
    midiLegatoParam.value = 0;
    triadParam.value = -1;
    bypassParam.value = 0;
    vgainParam.value = 1;
    hgainParam.value = 1;
    dryMixParam.value = 1;
    speedParam.value = 1;
    tuningParam.value = 440.0;
    threshParam.value = 0.1;
    stereoParam.value = 0;
    synthParam.value = 0;
    vibParam.value = 0;
    keycenterCCParam.value = 16;
    keycenterCcOffsetParam.value = 1;
    keyqualityCCParam.value = 17;
    keyqualityCcOffsetParam.value = 1;
    nvoicesCCParam.value = 18;
    inversionCCParam.value = 19;
    
    _sem = dispatch_semaphore_create(0);
    _kernel.sem = _sem;
        
    _kernel.setParameter(HarmParamKeycenter, keycenterParam.value);
    _kernel.setParameter(HarmParamInversion, inversionParam.value);
    _kernel.setParameter(HarmParamNvoices, nvoicesParam.value);
    _kernel.setParameter(HarmParamAuto, autoParam.value);
    _kernel.setParameter(HarmParamMidi, midiParam.value);
    _kernel.setParameter(HarmParamTriad, triadParam.value);
    _kernel.setParameter(HarmParamBypass, bypassParam.value);
    _kernel.setParameter(HarmParamStereo, stereoParam.value);
    
//    for (int k = 0; k < 144; k++)
//    {
//        keycenterIntervals[k].value = _kernel.getParameter(HarmParamInterval + k);
//    }
    
    // Create factory preset array.
	_currentFactoryPresetIndex = kDefaultFactoryPreset;
    _presets = @[NewAUPreset(0, @"Chords"),NewAUPreset(1, @"Diatonic"),NewAUPreset(2, @"Chromatic"),
                 NewAUPreset(3, @"Barbershop"),NewAUPreset(4,@"JustMidi"),NewAUPreset(5, @"Bohemian?"),NewAUPreset(6, @"Bass!"),NewAUPreset(7, @"4ths"), NewAUPreset(8, @"Modes")];
    
	// Create the parameter tree.
    _parameterTree = [AUParameterTree createTreeWithChildren:params];

	// Create the input and output busses.
	_inputBus.init(defaultFormat, 8);
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];

	// Create the input and output bus arrays.
	_inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus.bus]];
	_outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
    
	// Make a local pointer to the kernel to avoid capturing self.
	__block HarmonizerDSPKernel *filterKernel = &_kernel;

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
    
    keysDown = [[NSMutableArray alloc] initWithCapacity: 128];
    for (int k =0; k < 128; k++)
    {
        [keysDown addObject:[NSNumber numberWithBool:0]];
    }

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
    
    int outchannels = self.outputBus.format.channelCount;
    int inchannels = _inputBus.bus.format.channelCount;
	
    fprintf(stderr, "%d != %d\n", inchannels, outchannels);
    
//    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount) {
//        if (outError) {
//            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
//        }
//        // Notify superclass that initialization was not successful
//        self.renderResourcesAllocated = NO;
//
//        
//        NSLog(@"** can't allocate render resources, mismatched channel counts!\n");
//        
//        return NO;
//    }
    
    // start thread to listen for patch change events and update UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        while (true)
        {
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC));
            long result = dispatch_semaphore_wait(self->_kernel.sem, timeout);

            if (result == 0)
            {
                NSLog(@"signal received!\n");
                if (self.delegate)
                {
                    if (self->_kernel.pc_flag)
                    {
                        NSLog(@"programChange!\n");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate programChange:self->_kernel.program_change];
                        });
                        self->_kernel.pc_flag = 0;
                    }
                    if (self->_kernel.cc_flag)
                    {
                        NSLog(@"ccChange!\n");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate ccValue:self->_kernel.cc_val forCc:self->_kernel.cc_num];
                        });
                        self->_kernel.cc_flag = 0;
                    }
                }
            }
        }
    });
	
	_inputBus.allocateRenderResources(self.maximumFramesToRender);
	
	_kernel.init(inchannels, outchannels, self.outputBus.format.sampleRate);
	_kernel.reset();
	
	return YES;
}
	
- (void)deallocateRenderResources {
	_inputBus.deallocateRenderResources();
    _kernel.fini();
    [super deallocateRenderResources];
}

#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

- (NSArray<NSString *>*) MIDIOutputNames
{
    return @[@"midiOut"];
}

- (AUInternalRenderBlock)internalRenderBlock {
	/*
		Capture in locals to avoid ObjC member lookups. If "self" is captured in
        render, we're doing it wrong.
	*/
    NSLog(@"getting render block!");
    // Specify captured objects are mutable.
	__block HarmonizerDSPKernel *state = &_kernel;
	__block BufferedInputBus *input = &_inputBus;
    __block AUMIDIOutputEventBlock output_block = self.MIDIOutputEventBlock;
    
    return ^AUAudioUnitStatus(
			 AudioUnitRenderActionFlags *actionFlags,
			 const AudioTimeStamp       *timestamp,
			 AVAudioFrameCount           frameCount,
			 NSInteger                   outputBusNumber,
			 AudioBufferList            *outputData,
			 const AURenderEvent        *realtimeEventListHead,
			 AURenderPullInputBlock      pullInputBlock) {
		AudioUnitRenderActionFlags pullFlags = 0;

        if (frameCount > input->maxFrames) {
            return kAudioUnitErr_TooManyFramesToProcess;
        }
        
		AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
		
        //fprintf(stderr,"%x\n", pullFlags);
        
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
		state->processWithEvents(timestamp, frameCount, realtimeEventListHead, output_block);
        
//        if (output_block)
//        {
//            uint8_t bytes[3];
//            bytes[0] = 0x90;
//            bytes[1] = 60;
//            bytes[2] = 100;
//            output_block(AUEventSampleTimeImmediate, 0, 3, bytes);
//            bytes[0] = 0x80;
//            bytes[1] = 60;
//            bytes[2] = 100;
//            output_block(AUEventSampleTimeImmediate, 0, 3, bytes);
//        }
        
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
                
                AUParameter *inversionParameter = [self.parameterTree valueForKey: @"inversion"];
                AUParameter *autoParameter = [self.parameterTree valueForKey: @"auto"];
                AUParameter *nvoicesParameter = [self.parameterTree valueForKey: @"nvoices"];
                AUParameter *triadParameter = [self.parameterTree valueForKey: @"triad"];

                //keycenterParameter.value = presetParameters[factoryPreset.number].keycenterValue;
                inversionParameter.value = presetParameters[factoryPreset.number].inversionValue;
                autoParameter.value = presetParameters[factoryPreset.number].autoValue;
                nvoicesParameter.value = presetParameters[factoryPreset.number].nvoicesValue;
                triadParameter.value = presetParameters[factoryPreset.number].triadValue;
                
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

- (NSArray *) getNotes {
    NSMutableArray * output = [[NSMutableArray alloc] initWithCapacity: 5];
    
    NSNumber *n = [NSNumber numberWithInt:_kernel.midi_note_number];
    [output addObject:n];
    
    int nv = (int) _kernel.getParameter(HarmParamNvoices);
    
    for (int k = 0; k < 4; k++)
    {
        NSNumber *n = (k < nv) ? [NSNumber numberWithInt:_kernel.voice_notes[k]] : [NSNumber numberWithInt:-1];
        [output addObject:n];
    }
    
    return output;
}

- (NSArray *) getKeysDown {
    for (int k = 0; k < 128; k++)
    {
        [keysDown replaceObjectAtIndex:k withObject:[NSNumber numberWithBool:_kernel.keys_down[k]]];
    }
    
    return keysDown;
}

- (NSArray *) fields
{
    static NSArray *_fields;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fields = @[@"inversion",
                    @"auto",
                    @"nvoices",
                    @"triad",
                    @"speed",
                    @"h_gain",
                    @"v_gain"];
    });
    return _fields;
}

- (int) addMidiNote:(int)note_number vel:(int)velocity {
    _kernel.addnote(note_number, velocity);
    return 0;
}

- (int) remMidiNote:(int)note_number {
    _kernel.remnote(note_number);
    return 0;
}

- (float) getCurrentKeycenter {
    return _kernel.root_key;
}

- (float) getCurrentLevel {
    return _kernel.rms;
}

- (float) getCurrentNumVoices {
    return _kernel.getParameter(HarmParamNvoices);
}

- (float) getCurrentInversion {
    return _kernel.getParameter(HarmParamInversion);
}

- (int) setLoopMode:(int)mode {
    _kernel.setParameter(HarmParamLoop, (float) mode);
    return (int) _kernel.getParameter(HarmParamLoop);
}

- (int) getLoopMode {
    return _kernel.loop_mode;
}

- (float) getLoopPosition {
    return _kernel.loopPosition();
}

- (bool) isEmbedded {
    return embedded;
}

- (void) setEmbedded:(bool)embedded {
    embedded = embedded;
}

@end
