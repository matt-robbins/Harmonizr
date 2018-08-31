//
//  AudioEngine2.swift
//  HarmonizerApp
//
//  Created by Matthew E Robbins on 12/4/17.
//
import Foundation
import AudioToolbox
import CoreAudio
import AVFoundation
import UIKit

//func CheckError(_ error: OSStatus)
//{
//    if error == 0 {return}
//    print("Oh NOES!!")
//}

class AudioEngine2: NSObject {
    /// Playback engine.
    private var engine = AVAudioEngine()
    private let reverbUnitNode = AVAudioUnitReverb()
    private let delayUnitNode = AVAudioUnitDelay()
    private let nodes: [AVAudioNode] = [AVAudioNode]()
    
    private var sem = DispatchSemaphore(value: 0)
    
    /// Engine's test unit node.
    private var harmUnitNode: AVAudioUnit?
    private var midiReceiver: MidiReceiver? = nil
    var harmUnit: AUAudioUnit?
    var reverbUnit: AUAudioUnit?
    var outputUnit: AudioUnit?
    
    override init() {
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            //try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.mixWithOthers])
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.allowBluetoothA2DP, .mixWithOthers])
            //try session.setMode(AVAudioSessionModeMeasurement)
            try session.setPreferredIOBufferDuration(128/44000.0)
            try session.setPreferredSampleRate(44100.0)
            try session.setActive(true)
        }
        catch {
            fatalError("Can't configure audio session.")
        }
        #endif
        
        super.init()
        
        self.reverbUnit = reverbUnitNode.auAudioUnit
        
        // set up listener for inter-app audio configuration changes, since hte API is ugly, use a semaphore to trigger
        // a thread with access to a proper swift context
        
        DispatchQueue.global(qos: .background).async {
            while true {
                self.sem.wait()
                var connected: UInt32 = 0
                var data_size: UInt32 = 4
                AudioUnitGetProperty(self.engine.outputNode.audioUnit!, kAudioUnitProperty_IsInterAppConnected, kAudioUnitScope_Global, AudioUnitElement(0), &connected, &data_size)
                
                self.engine.stop()
                
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    try self.engine.start()
                }
                catch {
                    print("unable to start Audio Engine!!!: \(error)")
                }
            }
        }
        
        let proc: AudioUnitPropertyListenerProc = { (inRefCon, inUnit, inID, inScope, inElement) in
            let sem = inRefCon.assumingMemoryBound(to: DispatchSemaphore.self).pointee
            sem.signal()
        }
        
        AudioUnitAddPropertyListener(self.engine.outputNode.audioUnit!,kAudioUnitProperty_IsInterAppConnected, proc,UnsafeMutableRawPointer(&sem))
        
        var iaa_desc = AudioComponentDescription()
        iaa_desc.componentType = kAudioUnitType_RemoteEffect
        iaa_desc.componentSubType = 0x4861726d /*'Harm'*/
        iaa_desc.componentManufacturer = 0x4d724678 /*'MrFx'*/
        iaa_desc.componentFlags = 0
        iaa_desc.componentFlagsMask = 0
        
        AudioOutputUnitPublish(&iaa_desc,"MrFx: Harmonizer" as CFString,1,self.engine.outputNode.audioUnit!)
    
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: .AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
        
//        NotificationCenter.default.addObserver(forName: NSNotification.Name(String(kAudioComponentInstanceInvalidationNotification)), object: nil, queue: nil) { [weak self] notification in
//            //guard let strongSelf = self else { return }
//            /*
//             If the crashed audio unit was that of our type, remove it from
//             the signal chain. Note: we should notify the UI at this point.
//             */
//            let crashedAU = notification.object as? AUAudioUnit
//            print(notification)
//            print("\(String(describing: crashedAU!.audioUnitName)) crashed!!!")
//        }
        
    }
    
    public func bluetoothAudioConnected() -> Bool{
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        print(outputs)
        for output in outputs{
            if output.portType == AVAudioSessionPortBluetoothA2DP || output.portType == AVAudioSessionPortBluetoothHFP || output.portType == AVAudioSessionPortBluetoothLE
            {
                return true
            }
        }
        return false
    }

    @objc func handleRouteChange(_ notification: Notification) {
        
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSessionRouteChangeReason(rawValue:reasonValue) else {
                return
        }
        
        if (self.engine.isRunning)
        {
            self.engine.stop()
        }
        
        let session = AVAudioSession.sharedInstance()
        
        switch reason {
        case .newDeviceAvailable:
            for s in session.availableInputs! {
                print(s)
                if s.portType == AVAudioSessionPortHeadsetMic {
                    do {
                        try session.setPreferredInput(s)
                    }
                    catch {
                        print("couldn't set preferred input")
                    }
                }
            }
            
        // Handle new device available.
        case .oldDeviceUnavailable:
            for s in session.availableInputs! {
                print(s)
                if s.portType == AVAudioSessionPortUSBAudio {
                    do {
                        try session.setPreferredInput(s)
                    }
                    catch {
                        print("couldn't set preferred input")
                    }
                }
            }

        // Handle old device removed.
        default: ()
        }
        
        //session.currentRoute
        
        do {
            try session.setActive(true)
        }
        catch {
            //fatalError("Can't configure audio session.")
        }
        
        if (!self.engine.isRunning) {
            self.start()
        }
    }
    
    func start()
    {
        self.connectNodes()
        do {
            try engine.start()
        }
        catch {
            print("eek!")
        }
    }
    
    func stop()
    {
        self.engine.stop()
    }
    
    func loadComponent(componentDescription: AudioComponentDescription, completionHandler: @escaping ((AUAudioUnit) -> Void))
    {
        engine.attach(reverbUnitNode)
        
        //let hwFormat = input.inputFormat(forBus: 0)
        
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate,channels: 2)
        
        self.engine.connect(self.engine.inputNode, to: self.engine.mainMixerNode, format: stereoFormat)
        
        outputUnit = engine.outputNode.audioUnit
        
        AVAudioUnit.instantiate(with: componentDescription, options: []) { avAudioUnit, error in
            guard let avAudioUnit = avAudioUnit else { return }

            self.harmUnitNode = avAudioUnit
            self.harmUnit = avAudioUnit.auAudioUnit
            
            //self.harmUnit?.currentPreset = self.harmUnit?.factoryPresets?[0]
            
            self.engine.attach(self.harmUnitNode!)

            self.connectNodes()

            self.midiReceiver = MidiReceiver.init(audioUnit: self.harmUnit)

            completionHandler(self.harmUnit!)
        }
    }
    
    func connectNodes()
    {
        if (self.harmUnitNode == nil)
        {
            return
        }
        
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: AVAudioSession.sharedInstance().sampleRate,channels: 2)
        
        self.engine.disconnectNodeInput(self.engine.mainMixerNode)
        self.engine.disconnectNodeInput(self.reverbUnitNode)
        self.engine.disconnectNodeInput(self.harmUnitNode!)

        self.engine.connect(self.engine.mainMixerNode, to: self.engine.outputNode, format: stereoFormat)

        self.engine.connect(self.engine.inputNode, to: self.harmUnitNode!, format: stereoFormat)
        self.engine.connect(self.harmUnitNode!, to: self.reverbUnitNode, format: stereoFormat)

//        self.engine.connect(self.engine.inputNode!, to: self.reverbUnitNode, format: stereoFormat)
        self.engine.connect(self.reverbUnitNode, to: self.engine.mainMixerNode, format: stereoFormat)
    }
    
}
