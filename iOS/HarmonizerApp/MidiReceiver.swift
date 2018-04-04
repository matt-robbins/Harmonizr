//
//  MidiReceiver.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 12/4/17.
//

import Foundation
import AVFoundation


class MidiReceiver : NSObject {
    
    private var midiClient = MIDIClientRef()
    
    private var outputPort = MIDIPortRef()
    
    private var inputPort = MIDIPortRef()
    private var noteBlock: AUScheduleMIDIEventBlock
    
    let cbytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    
    internal init?(audioUnit: AUAudioUnit?) {
        guard audioUnit != nil else { return nil }
        guard let theNoteBlock = audioUnit!.scheduleMIDIEventBlock else { print("Blam! schedule"); return nil }
        
        noteBlock = theNoteBlock
        super.init()
        setupMidi()
    }
    
    func setupMidi()
    {
        //print (MIDIGetNumberOfSources())
        
        observeNotifications()
        enableNetwork()
        
        let notifyBlock = MyMIDINotifyBlock
        
        var status = MIDIClientCreateWithBlock("Harmonizer" as CFString, &midiClient, notifyBlock)
        
        if status != noErr {
            print("error creating client : \(status)")
        }
        
        let readBlock:MIDIReadBlock = MyMIDIReadBlock
        
        if status == noErr
        {
            status = MIDIInputPortCreateWithBlock(midiClient, "Harmonizer.input" as CFString, &inputPort, readBlock)
            if status != noErr {
                print("error creating input port %d", status)
            }
        }
        
        midiConnect()
    }
    func observeNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(midiNetworkChanged(notification:)),
                                               name:NSNotification.Name(rawValue: MIDINetworkNotificationSessionDidChange),
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(midiNetworkContactsChanged(notification:)),
                                               name:NSNotification.Name(rawValue: MIDINetworkNotificationContactsDidChange),
                                               object: nil)
    }
    
    // signifies that other aspects of the session changed, such as the connection list, connection policy
    func midiNetworkChanged(notification:NSNotification) {
        print("\(#function)")
        print("\(notification)")
        if let session = notification.object as? MIDINetworkSession {
            print("session \(session)")
            for con in session.connections() {
                print("con \(con)")
            }
            print("isEnabled \(session.isEnabled)")
            print("sourceEndpoint \(session.sourceEndpoint())")
            print("destinationEndpoint \(session.destinationEndpoint())")
            print("networkName \(session.networkName)")
            print("localName \(session.localName)")
            
            if let name = getDeviceName(session.sourceEndpoint()) {
                print("source name \(name)")
            }
            
            if let name = getDeviceName(session.destinationEndpoint()) {
                print("destination name \(name)")
            }
        }
    }
    
    func midiNetworkContactsChanged(notification:NSNotification) {
        print("\(#function)")
        print("\(notification)")
        if let session = notification.object as? MIDINetworkSession {
            print("session \(session)")
            for con in session.contacts() {
                print("contact \(con)")
            }
        }
    }
    func enableNetwork() {
        MIDINetworkSession.default().isEnabled = true
        MIDINetworkSession.default().connectionPolicy = .anyone
    }
    
    func MyMIDIReadBlock(packetList: UnsafePointer<MIDIPacketList>, srcConnRefCon: UnsafeMutableRawPointer?) -> Swift.Void {
        
        let packets = packetList.pointee
        
        let packet:MIDIPacket = packets.packet
        
        var ap = UnsafeMutablePointer<MIDIPacket>.allocate(capacity: 1)
        ap.initialize(to:packet)
        
        for _ in 0 ..< packets.numPackets {
            let p = ap.pointee
            handle(p)
            
            ap = MIDIPacketNext(ap)
        }
    }
    
    func handle(_ packet:MIDIPacket) {
        
        let status = packet.data.0
        let d1 = packet.data.1
        //let d2 = packet.data.2
        let rawStatus = status & 0xF0 // without channel
        let channel = status & 0x0F
        
        cbytes[0] = packet.data.0
        cbytes[1] = packet.data.1
        cbytes[2] = packet.data.2
        
        switch rawStatus {
            
        case 0x80:
            //print("Note off. Channel \(channel) note \(d1) velocity \(d2)")
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            // forward to sampler
            
        case 0x90:
            //print("Note on. Channel \(channel) note \(d1) velocity \(d2)")
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            // forward to sampler
            
        case 0xA0: // poly aftertouch
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            
        case 0xB0: // control
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            
        case 0xC0:
            print("Program Change. Channel \(channel) program \(d1)")
            
        case 0xD0: // mono aftertouch
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            
        case 0xE0: // pitch bend
            self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
            
        default:
            return
        }
    }
    
    func MyMIDINotifyBlock(midiNotification: UnsafePointer<MIDINotification>) {
        print("\ngot a MIDINotification!")
        
        let notification = midiNotification.pointee
        print("MIDI Notify, messageId= \(notification.messageID)")
        print("MIDI Notify, messageSize= \(notification.messageSize)")
        
        switch notification.messageID {
            
        // Some aspect of the current MIDISetup has changed.  No data.  Should ignore this  message if messages 2-6 are handled.
        case .msgSetupChanged:
            print("MIDI setup changed")
            let ptr = UnsafeMutablePointer<MIDINotification>(mutating: midiNotification)
            //            let ptr = UnsafeMutablePointer<MIDINotification>(midiNotification)
            let m = ptr.pointee
            print(m)
            print("id \(m.messageID)")
            print("size \(m.messageSize)")
            break
            
            
        // A device, entity or endpoint was added. Structure is MIDIObjectAddRemoveNotification.
        case .msgObjectAdded:
            
            print("added")
            //            let ptr = UnsafeMutablePointer<MIDIObjectAddRemoveNotification>(midiNotification)
            
            midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                let m = $0.pointee
                print(m)
                print("id \(m.messageID)")
                print("size \(m.messageSize)")
                print("child \(m.child)")
                print("child type \(m.childType)")
                print("parent \(m.parent)")
                print("parentType \(m.parentType)")
                print("childName \(String(describing: getDeviceName(m.child)))")
            }
            
            
            break
            
        // A device, entity or endpoint was removed. Structure is MIDIObjectAddRemoveNotification.
        case .msgObjectRemoved:
            print("kMIDIMsgObjectRemoved")
            //            let ptr = UnsafeMutablePointer<MIDIObjectAddRemoveNotification>(midiNotification)
            midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                
                let m = $0.pointee
                print(m)
                print("id \(m.messageID)")
                print("size \(m.messageSize)")
                print("child \(m.child)")
                print("child type \(m.childType)")
                print("parent \(m.parent)")
                print("parentType \(m.parentType)")
                
                print("childName \(String(describing: getDeviceName(m.child)))")
            }
            
            
            break
            
        // An object's property was changed. Structure is MIDIObjectPropertyChangeNotification.
        case .msgPropertyChanged:
            print("kMIDIMsgPropertyChanged")
            
            
            
            //            let ptr = UnsafeMutablePointer<MIDIObjectPropertyChangeNotification>(midiNotification)
            midiNotification.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
                
                let m = $0.pointee
                print(m)
                print("id \(m.messageID)")
                print("size \(m.messageSize)")
                print("object \(m.object)")
                print("objectType  \(m.objectType)")
                print("propertyName  \(m.propertyName)")
                print("propertyName  \(m.propertyName.takeUnretainedValue())")
                
                if m.propertyName.takeUnretainedValue() as String == "apple.midirtp.session" {
                    print("connected")
                }
            }
            
            break
            
        //     A persistent MIDI Thru connection wasor destroyed.  No data.
        case .msgThruConnectionsChanged:
            print("MIDI thru connections changed.")
            break
            
        //A persistent MIDI Thru connection was created or destroyed.  No data.
        case .msgSerialPortOwnerChanged:
            print("MIDI serial port owner changed.")
            break
            
        case .msgIOError:
            print("MIDI I/O error.")
            
            //let ptr = UnsafeMutablePointer<MIDIIOErrorNotification>(midiNotification)
            midiNotification.withMemoryRebound(to: MIDIIOErrorNotification.self, capacity: 1) {
                let m = $0.pointee
                print(m)
                print("id \(m.messageID)")
                print("size \(m.messageSize)")
                print("driverDevice \(m.driverDevice)")
                print("errorCode \(m.errorCode)")
            }
            break
        }
        
        midiConnect()
    }
    
    func getDeviceName(_ endpoint:MIDIEndpointRef) -> String? {
        var cfs: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfs)
        if status != noErr {
            print("error getting device name for")
        }
        
        if let s = cfs {
            return s.takeRetainedValue() as String
        }
        
        return nil
    }
    
    
    func midiConnect()
    {
        let sourceCount = MIDIGetNumberOfSources()
        
        for srcIndex in 0 ..< sourceCount {
            let midiEndPoint = MIDIGetSource(srcIndex)
            
            let status = MIDIPortConnectSource(inputPort,midiEndPoint,nil)
            
            if status != noErr {
                print("oh crap! couldn't connect", status)
            }
        }
    }
}

