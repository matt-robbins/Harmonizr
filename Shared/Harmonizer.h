/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	An AUAudioUnit subclass implementing a low-pass filter with resonance. Illustrates parameter management and rendering, including in-place processing and buffer management.
*/

#ifndef FilterDemo_h
#define FilterDemo_h

#import <AudioToolbox/AudioToolbox.h>

@protocol HarmonizerDelegate <NSObject>

@optional
- (void)programChange:(int)program;

@end

@interface AUv3Harmonizer : AUAudioUnit

- (NSArray *) fields;
- (float) getCurrentNote;
- (NSArray *) getNotes;
- (int) addMidiNote:(int)note_number vel:(int)velocity;
- (int) remMidiNote:(int)note_number;
- (float) getCurrentKeycenter;
@property (nonatomic, weak) id<HarmonizerDelegate> delegate;
@end

#endif /* FilterDemo_h */
