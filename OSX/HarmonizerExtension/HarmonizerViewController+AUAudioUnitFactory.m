/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	`FilterDemoViewController` is the app extension's principal class, responsible for creating both the audio unit and its view.
*/

#import "HarmonizerViewController+AUAudioUnitFactory.h"

@implementation HarmonizerViewController (AUAudioUnitFactory)

- (AUv3Harmonizer *) createAudioUnitWithComponentDescription:(AudioComponentDescription) desc error:(NSError **)error {
    self.audioUnit = [[AUv3Harmonizer alloc] initWithComponentDescription:desc error:error];
    return self.audioUnit;
}

@end
