/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	FilterDemoViewController is the app extension's principal class, responsible for creating both the audio unit and its view.
*/

import CoreAudioKit
import HarmonizerFramework

extension HarmonizrMainViewController: AUAudioUnitFactory {
    /*
        This implements the required `NSExtensionRequestHandling` protocol method.
        Note that this may become unnecessary in the future, if `AUViewController`
        implements the override.
     */
    public override func beginRequest(with context: NSExtensionContext) { }
    
    /*
        This implements the required `AUAudioUnitFactory` protocol method.
        When this view controller is instantiated in an extension process, it
        creates its audio unit.
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try AUv3Harmonizer(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
    
    public func requestViewController(completionHandler: @escaping (UIViewController?) -> Void)
    {
        completionHandler(self)
    }
}
