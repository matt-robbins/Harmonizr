/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	An AUAudioUnit subclass implementing a low-pass filter with resonance. Illustrates parameter management and rendering, including in-place processing and buffer management.
*/

#ifndef Harmonizer_h
#define Harmonizer_h

#import <AudioToolbox/AudioToolbox.h>

@protocol HarmonizerDelegate <NSObject>

@optional
- (void)programChange:(int)program;
- (void)ccValue:(int)value forCc:(int)cc;

@end

@interface AUv3Harmonizer : AUAudioUnit

- (NSArray *) fields;
- (float) getCurrentNote;
- (NSArray *) getNotes;
- (NSArray *) getKeysDown;
- (int) addMidiNote:(int)note_number vel:(int)velocity;
- (int) remMidiNote:(int)note_number;
- (float) getCurrentLevel;
- (float) getCurrentKeycenter;
- (float) getCurrentNumVoices;
- (float) getCurrentInversion;
- (int) setLoopMode:(int)mode;
- (int) getLoopMode;
- (float) getLoopPosition;
- (void) setEmbedded:(bool)embedded;
- (bool) isEmbedded;

@property (nonatomic, weak) id<HarmonizerDelegate> delegate;
@end

#endif /* Harmonizer_h */
