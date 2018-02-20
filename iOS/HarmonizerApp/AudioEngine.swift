//
//  AudioEngine.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 12/1/17.
//
//
import Foundation
import AudioToolbox
import CoreAudio
import AVFoundation

func CheckError(_ error: OSStatus)
{
    if error == 0 {return}
    switch error {
    // AudioToolbox
    case kAUGraphErr_NodeNotFound:
        print("Error:kAUGraphErr_NodeNotFound")
        
    case kAUGraphErr_OutputNodeErr:
        print( "Error:kAUGraphErr_OutputNodeErr")
        
    case kAUGraphErr_InvalidConnection:
        print("Error:kAUGraphErr_InvalidConnection")
        
    case kAUGraphErr_CannotDoInCurrentContext:
        print( "Error:kAUGraphErr_CannotDoInCurrentContext")
        
    case kAUGraphErr_InvalidAudioUnit:
        print( "Error:kAUGraphErr_InvalidAudioUnit")
        
    case kAudioToolboxErr_InvalidSequenceType :
        print( " kAudioToolboxErr_InvalidSequenceType")
        
    case kAudioToolboxErr_TrackIndexError :
        print( " kAudioToolboxErr_TrackIndexError")
        
    case kAudioToolboxErr_TrackNotFound :
        print( " kAudioToolboxErr_TrackNotFound")
        
    case kAudioToolboxErr_EndOfTrack :
        print( " kAudioToolboxErr_EndOfTrack")
        
    case kAudioToolboxErr_StartOfTrack :
        print( " kAudioToolboxErr_StartOfTrack")
        
    case kAudioToolboxErr_IllegalTrackDestination    :
        print( " kAudioToolboxErr_IllegalTrackDestination")
        
    case kAudioToolboxErr_NoSequence         :
        print( " kAudioToolboxErr_NoSequence")
        
    case kAudioToolboxErr_InvalidEventType        :
        print( " kAudioToolboxErr_InvalidEventType")
        
    case kAudioToolboxErr_InvalidPlayerState    :
        print( " kAudioToolboxErr_InvalidPlayerState")
        
    case kAudioUnitErr_InvalidProperty        :
        print( " kAudioUnitErr_InvalidProperty")
        
    case kAudioUnitErr_InvalidParameter        :
        print( " kAudioUnitErr_InvalidParameter")
        
    case kAudioUnitErr_InvalidElement        :
        print( " kAudioUnitErr_InvalidElement")
        
    case kAudioUnitErr_NoConnection            :
        print( " kAudioUnitErr_NoConnection")
        
    case kAudioUnitErr_FailedInitialization        :
        print( " kAudioUnitErr_FailedInitialization")
        
    case kAudioUnitErr_TooManyFramesToProcess    :
        print( " kAudioUnitErr_TooManyFramesToProcess")
        
    case kAudioUnitErr_InvalidFile            :
        print( " kAudioUnitErr_InvalidFile")
        
    case kAudioUnitErr_FormatNotSupported        :
        print( " kAudioUnitErr_FormatNotSupported")
        
    case kAudioUnitErr_Uninitialized        :
        print( " kAudioUnitErr_Uninitialized")
        
    case kAudioUnitErr_InvalidScope            :
        print( " kAudioUnitErr_InvalidScope")
        
    case kAudioUnitErr_PropertyNotWritable        :
        print( " kAudioUnitErr_PropertyNotWritable")
        
    case kAudioUnitErr_InvalidPropertyValue        :
        print( " kAudioUnitErr_InvalidPropertyValue")
        
    case kAudioUnitErr_PropertyNotInUse        :
        print( " kAudioUnitErr_PropertyNotInUse")
        
    case kAudioUnitErr_Initialized            :
        print( " kAudioUnitErr_Initialized")
        
    case kAudioUnitErr_InvalidOfflineRender        :
        print( " kAudioUnitErr_InvalidOfflineRender")
        
    case kAudioUnitErr_Unauthorized            :
        print( " kAudioUnitErr_Unauthorized")
        
    default:
        print("huh?")
    }
    
    fatalError("Yikes!!!")
}

class AudioEngine: NSObject {
    var processingGraph: AUGraph?
    var effectNode: AUNode
    var ioNode: AUNode
    var effectUnit: AudioUnit?
    var ioUnit: AudioUnit?
    var isPlaying: Bool
    
    var stereoFormat: AudioStreamBasicDescription
    
    override init() {
        self.processingGraph = nil
        self.effectNode     = AUNode()
        self.ioNode          = AUNode()
        self.effectUnit     = nil
        self.ioUnit          = nil
        self.isPlaying       = false
        
        let session = AVAudioSession.sharedInstance()
        
        self.stereoFormat = AudioStreamBasicDescription()
        stereoFormat.mChannelsPerFrame = 2 // stereo
        stereoFormat.mSampleRate = session.sampleRate
        stereoFormat.mFormatID = kAudioFormatLinearPCM
        stereoFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved
        stereoFormat.mBytesPerFrame = UInt32(MemoryLayout<Float32>.size)
        stereoFormat.mBytesPerPacket = UInt32(MemoryLayout<Float32>.size)
        stereoFormat.mBitsPerChannel = 32
        stereoFormat.mFramesPerPacket  = 1
        
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try session.setMode(AVAudioSessionModeMeasurement)
            try session.setPreferredIOBufferDuration(0.01)
            try session.setActive(true)
        }
        catch {
            fatalError("Can't configure audio session.")
        }
        
        super.init()
        
        augraphSetup()
        graphStart()
    }
    
//    func setAudioUnit(unit: AudioUnit)
//    {
//        self.effectUnit = unit
//
//
//    }
    
    
    func augraphSetup() {
        var status = OSStatus(noErr)
        status = NewAUGraph(&processingGraph)
        CheckError(status)

        var cd = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_MusicEffect),
            componentSubType: OSType(0x4861726d), //0x4861726d
            componentManufacturer: OSType(0x4d724678), //0x4d724678
            componentFlags: 0,
            componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph!, &cd, &effectNode)
        CheckError(status)
        
        var ioUnitDescription = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Output),
            componentSubType: OSType(kAudioUnitSubType_RemoteIO),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph!, &ioUnitDescription, &ioNode)
        CheckError(status)
        
        // open graph
        status = AUGraphOpen(self.processingGraph!)
        CheckError(status)
        
        // grab audio units
        status = AUGraphNodeInfo(self.processingGraph!, self.effectNode, nil, &effectUnit)
        CheckError(status)
        status = AUGraphNodeInfo(self.processingGraph!, self.ioNode, nil, &ioUnit)
        CheckError(status)
        
        // enable input and output
        var flag: UInt32 = 1
                
        status = AudioUnitSetProperty(ioUnit!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, AudioUnitElement(1), &flag, UInt32(4))
        CheckError(status)
        status = AudioUnitSetProperty(ioUnit!, OSType(kAudioOutputUnitProperty_EnableIO), OSType(kAudioUnitScope_Output), AudioUnitElement(0), &flag, UInt32(4))
        CheckError(status)
        
        // set up stereo format for effect unit
        status = AudioUnitSetProperty(effectUnit!, kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, AudioUnitElement(0), &stereoFormat,UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        CheckError(status)
        
        // stereo for io unit
        status = AudioUnitSetProperty(ioUnit!, kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, AudioUnitElement(1), &stereoFormat,UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        CheckError(status)
        
        var maxFrames: UInt32 = 4096
        
        status = AudioUnitSetProperty(ioUnit!,kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, AudioUnitElement(0), &maxFrames, UInt32(MemoryLayout<UInt32>.size))
            
        // finally make connections
        status = AUGraphConnectNodeInput(self.processingGraph!, self.effectNode, AudioUnitElement(0), self.ioNode, AudioUnitElement(0))
        CheckError(status)
        
        status = AUGraphConnectNodeInput(self.processingGraph!, self.ioNode, AudioUnitElement(1), self.effectNode, AudioUnitElement(0))
        CheckError(status)
        
        
        var iaa_desc = AudioComponentDescription()
        iaa_desc.componentType = kAudioUnitType_RemoteEffect
        iaa_desc.componentSubType = 0x4861726d /*'Harm'*/
        iaa_desc.componentManufacturer = 0x4d724678 /*'MrFx'*/
        iaa_desc.componentFlags = 0
        iaa_desc.componentFlagsMask = 0

        AudioOutputUnitPublish(&iaa_desc,"MrFx: Harmonizer" as CFString, 1, ioUnit!)
        
        
        // print info to stdout for debugging
        CAShow(UnsafeMutablePointer<AUGraph>(self.processingGraph!))
        
    }
    
    func graphStart() {
        //https://developer.apple.com/library/prerelease/ios/documentation/AudioToolbox/Reference/AUGraphServicesReference/index.html#//apple_ref/c/func/AUGraphIsInitialized
        
        var status = OSStatus(noErr)
        var outIsInitialized = DarwinBoolean(false)
        status = AUGraphIsInitialized(self.processingGraph!, &outIsInitialized)
        print("isinit status is \(status)")
        print("bool is \(outIsInitialized)")
        if !outIsInitialized.boolValue {
            status = AUGraphInitialize(self.processingGraph!)
            CheckError(status)
        }
        
        var isRunning = DarwinBoolean(false)
        AUGraphIsRunning(self.processingGraph!, &isRunning)
        print("running bool is \(isRunning)")
        if !isRunning.boolValue {
            status = AUGraphStart(self.processingGraph!)
            CheckError(status)
        }
        
        self.isPlaying = true
    }
    
    func playNoteOn(_ noteNum: UInt32, velocity: UInt32) {
        // note on command on channel 0
        let noteCommand = UInt32(0x90 | 0)
        var status = OSStatus(noErr)
        status = MusicDeviceMIDIEvent(self.effectUnit!, noteCommand, noteNum, velocity, 0)
        CheckError(status)
        print("noteon status is \(status)")
    }
    
    func playNoteOff(_ noteNum: UInt32) {
        // note off command on channel 0
        let noteCommand = UInt32(0x80 | 0)
        var status = OSStatus(noErr)
        status = MusicDeviceMIDIEvent(self.effectUnit!, noteCommand, noteNum, 0, 0)
        CheckError(status)
        print("noteoff status is \(status)")
    }
}
