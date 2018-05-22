/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	An AUAudioUnit subclass implementing a low-pass filter with resonance. Illustrates parameter management and rendering, including in-place processing and buffer management.
*/

#ifndef FilterDemo_h
#define FilterDemo_h

#import <AudioToolbox/AudioToolbox.h>

@interface AUv3Harmonizer : AUAudioUnit

- (float) getCurrentNote;
- (float) getMidiNote;
- (float) getCurrentKeycenter;
@end

#endif /* FilterDemo_h */
