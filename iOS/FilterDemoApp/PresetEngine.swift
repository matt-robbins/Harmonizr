//
//  PresetEngine.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 1/10/18.
//

import Foundation
import AudioUnit
import AudioToolbox

public class Preset: NSObject, NSCoding {
    struct PropertyKey {
        static let name = "name"
        static let data = "data"
        static let isFactory = "isFactory"
    }
    
    public var name: String? = nil
    public var data: Any? = nil
    public var isFactory: Bool = false
    
    init (name: String, data: Any?, isFactory: Bool) {
        self.name = name
        self.data = data
        self.isFactory = isFactory
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(data, forKey: PropertyKey.data)
        aCoder.encode(isFactory, forKey: PropertyKey.isFactory)
    }
    
    public required convenience init?(coder aDecoder: NSCoder)
    {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else {
            //os_log("Unable to decode the name for a Preset object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let data = aDecoder.decodeObject(forKey: PropertyKey.data)
        let isFactory = aDecoder.decodeBool(forKey: PropertyKey.isFactory)
        
        // Must call designated initializer.
        self.init(name: name, data: data, isFactory: isFactory)
    }
}

public class PresetEngine: NSObject, NSCoding {
    var presets: [Preset] = [Preset]()
    var audioUnits: [AUAudioUnit]
    var presetIx = 0
    
    init (npresets: Int, audioUnits: [AUAudioUnit])
    {
        self.audioUnits = audioUnits
    }
    
    public func encode(with coder: NSCoder)
    {
        
    }
    
    public required convenience init?(coder aDecoder: NSCoder)
    {
        self.init(npresets: 10, audioUnits: [AUAudioUnit]())
    }
    
    
    func loadPresets() {
        // TODO: Load presets array from file
        presets = [Preset]()
    }
    
    func storePresets() {
        // TODO: store presets to file
    }
    
    func getAUData() -> String
    {
        // get state from all audio units and serialize
        return ""
    }
    
    func setAUData(data: Any)
    {
        // TODO: deserialize and write audio unit states
    }
    
    func storePreset(_ name: String, index: Int) {
        
        let p = Preset(name: name, data: getAUData(), isFactory: false)
        
        if (index >= presets.count)
        {
            presets.append(p)
            presetIx = presets.count - 1
        }
        else
        {
            presets[index] = p
            presetIx = index
        }
        
        storePresets()
    }
    
    func loadPreset(index: Int) {
        setAUData(data: presets[index].data!)
    }
    

}
