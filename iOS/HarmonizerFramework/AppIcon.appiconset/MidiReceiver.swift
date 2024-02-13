//
//  MidiReceiver.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 12/4/17.
//

import Foundation
import AVFoundation

//extension MIDIPacket {
//    var dataBytes: [UInt8] {
//        mutating get {
//            return withUnsafePointer(&data) { tuplePointer in
//                let elementPointer = UnsafePointer<UInt8>(tuplePointer)
//                return (0..<Int(length)).map { elementPointer[$0] }
//            }
//        }
//    }
//}

//status values: note off, note on, poly aftertouch, control, program change, mono aftertouch, pitch bend
enum MIDIStatus: UInt8 {
    case noteOff = 0x80
    case noteOn = 0x90
    case polyAftertouch = 0xA0
    case controlChange = 0xB0
    case programChange = 0xC0
    case monoAftertouch = 0xD0
    case pitchBend = 0xE0
}

class MidiReceiver : NSObject {
    
    private var midiClient = MIDIClientRef()
    
    private var outputPort = MIDIPortRef()
    
    private var inputPort = MIDIPortRef()
    private var noteBlock: AUScheduleMIDIEventBlock
    
    let cbytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
    let ccmd = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
    
    internal init?(audioUnit: AUAudioUnit?) {
        guard audioUnit != nil else { return nil }
        guard let theNoteBlock = audioUnit!.scheduleMIDIEventBlock else { return nil }
        
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
            
//            status = MIDIOutputPortCreate(midiClient, "Harmonizer.output" as CFString, &outputPort)
//            if status != noErr {
//                print("error creating output port %d", status)
//            }
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
    @objc func midiNetworkChanged(notification:NSNotification) {
        
//        if let session = notification.object as? MIDINetworkSession {
//            break
//        }
    }
    
    @objc func midiNetworkContactsChanged(notification:NSNotification) {
        
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
    
    func handle(_ packet: MIDIPacket) {
        
        let status = packet.data.0
        let rawStatus: MIDIStatus = MIDIStatus(rawValue: status & 0xF0) ?? MIDIStatus.noteOff // without channel
       // let channel = status & 0x0F
        
        // copy the packet to get the data bytes layed out in memory the right way.
        var p = packet
        
        withUnsafeMutablePointer(to: &p.data) {
            $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout.size(ofValue: packet.data)) {
                dataPtr in // `dataPtr` is an `UnsafeMutablePointer<UInt8>`
                
                for i in 0..<Int(packet.length) {
                    //print(dataPtr[i])
                    cbytes[i] = dataPtr[i]
                }
            }
        }
        
        ccmd[0] = status
        
        switch rawStatus {
            
        case .programChange:
            ccmd[1] = cbytes[1];
            self.noteBlock(AUEventSampleTimeImmediate, 0, 2, ccmd)
            
        case .noteOn, .noteOff, .polyAftertouch, .controlChange, .monoAftertouch, .pitchBend:
            var ix = 1
            // handle "running status" in packets, where status bytes may be omitted for transmitting many messages with the same status
            while (ix + 1 < packet.length)
            {
                ccmd[1] = cbytes[ix]
                ccmd[2] = cbytes[ix+1]
                self.noteBlock(AUEventSampleTimeImmediate, 0, 3, ccmd)
                ix += 2
            }
        }
    }
    
    func MyMIDINotifyBlock(midiNotification: UnsafePointer<MIDINotification>) {
        
        let notification = midiNotification.pointee
        
        switch notification.messageID {
            
        // Some aspect of the current MIDISetup has changed.  No data.  Should ignore this  message if messages 2-6 are handled.
        case .msgSetupChanged:
            //let ptr = UnsafeMutablePointer<MIDINotification>(mutating: midiNotification)
            //            let ptr = UnsafeMutablePointer<MIDINotification>(midiNotification)
            //let m = ptr.pointee
            break
            
            
        // A device, entity or endpoint was added. Structure is MIDIObjectAddRemoveNotification.
        case .msgObjectAdded:
                        
            midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                let m = $0.pointee
                print(m)
            }
            
            break
            
        // A device, entity or endpoint was removed. Structure is MIDIObjectAddRemoveNotification.
        case .msgObjectRemoved:
            //            let ptr = UnsafeMutablePointer<MIDIObjectAddRemoveNotification>(midiNotification)
            midiNotification.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                
                let m = $0.pointee
                print(m)
            }
            
            break
            
        // An object's property was changed. Structure is MIDIObjectPropertyChangeNotification.
        case .msgPropertyChanged:
            
            //            let ptr = UnsafeMutablePointer<MIDIObjectPropertyChangeNotification>(midiNotification)
            midiNotification.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
                
                let m = $0.pointee

                if m.propertyName.takeUnretainedValue() as String == "apple.midirtp.session" {
                    print("connected")
                }
            }
            
            break
            
        //     A persistent MIDI Thru connection wasor destroyed.  No data.
        case .msgThruConnectionsChanged:
            break
            
        //A persistent MIDI Thru connection was created or destroyed.  No data.
        case .msgSerialPortOwnerChanged:
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
        
//        let N = MIDIGetNumberOfDestinations()
//        for ix in 0 ..< N {
//            let dst = MIDIGetDestination(ix)
//            let status = MIDIPortConnectSource(dst, outputPort, nil)
//
//            if status != noErr {
//                print("oh crap! couldn't connect output port", status)
//            }
//        }
        
    }
}

