//
//  AudioEngine2.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 12/4/17.
//

import Foundation
//
//  AudioEngine.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 12/1/17.
//

import Foundation

//
//  SoundGenerator.swift
//  SwiftSimpleAUGraph
//
//  Created by Gene De Lisa on 6/8/14.
//  Copyright (c) 2014 Gene De Lisa. All rights reserved.
//
import Foundation
import AudioToolbox
import CoreAudio
import AVFoundation

//func CheckError(_ error: OSStatus)
//{
//    if error == 0 {return}
//    print("Oh NOES!!")
//}

class AudioEngine2: NSObject {
    /// Playback engine.
    private let engine = AVAudioEngine()
    private let reverbUnitNode = AVAudioUnitReverb()
    
    /// Engine's test unit node.
    private var harmUnitNode: AVAudioUnit?
    private var midiReceiver: MidiReceiver? = nil
    var harmUnit: AUAudioUnit?
    var reverbUnit: AUAudioUnit?
    
    override init() {
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try session.setMode(AVAudioSessionModeMeasurement)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        }
        catch {
            fatalError("Can't configure audio session.")
        }
        #endif
        
        super.init()
        
        self.reverbUnit = reverbUnitNode.auAudioUnit
    }
    
    func start()
    {
        do {
            try engine.start()
        }
        catch {
            print("eek!")
        }
        
    }
    
    func loadComponent(componentDescription: AudioComponentDescription, completionHandler: @escaping ((AUAudioUnit) -> Void))
    {
        engine.attach(reverbUnitNode)

        
        let input = self.engine.inputNode!
        let format = input.inputFormat(forBus: 0)

        //self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: self.engine.outputNode.outputFormat(forBus: 0))

        // connect audio input to harmonizer node
        //self.engine.connect(input, to: self.reverbUnitNode, format: format)

        self.engine.connect(self.engine.inputNode!, to: self.engine.mainMixerNode, format: format)

        do {
            try self.engine.start()
        }
        catch {
            print("unable to start Audio Engine!!!: \(error)")
        }
        
        AVAudioUnit.instantiate(with: componentDescription, options: []) { avAudioUnit, error in
            guard let avAudioUnit = avAudioUnit else { return }

            self.harmUnitNode = avAudioUnit

            let input = self.engine.inputNode!
            let format = input.inputFormat(forBus: 0)
        
            self.engine.disconnectNodeInput(self.engine.mainMixerNode)
            self.engine.attach(self.harmUnitNode!)
            
            self.engine.connect(self.engine.inputNode!, to: avAudioUnit, format: format)
            self.engine.connect(avAudioUnit, to: self.reverbUnitNode, format: format)
            self.engine.connect(self.reverbUnitNode, to: self.engine.mainMixerNode, format: format)

            self.harmUnit = avAudioUnit.auAudioUnit
            avAudioUnit.auAudioUnit.contextName = "Harmonizer"
            
            self.midiReceiver = MidiReceiver.init(audioUnit: self.harmUnit)

//            var iaa_desc = AudioComponentDescription()
//            iaa_desc.componentType = kAudioUnitType_RemoteEffect
//            iaa_desc.componentSubType = 0x4861726d /*'Harm'*/
//            iaa_desc.componentManufacturer = 0x4d724678 /*'MrFx'*/
//            iaa_desc.componentFlags = 0
//            iaa_desc.componentFlagsMask = 0
//
//            AudioOutputUnitPublish(&iaa_desc,"MrFx: Harmonizer" as CFString,1,self.engine.outputNode.audioUnit!)

            completionHandler(self.harmUnit!)
        }
    }
}
