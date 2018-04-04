//
//  PresetController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 3/26/18.
//

import UIKit

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
        
        // Because photo is an optional property of Meal, just use conditional cast.
        let data = aDecoder.decodeObject(forKey: PropertyKey.data)
        
        let isFactory = aDecoder.decodeBool(forKey: PropertyKey.isFactory)
        
        // Must call designated initializer.
        self.init(name: name, data: data, isFactory: isFactory)
    }
}

class PresetController: NSObject {
    
    public var audioUnit: AUv3Harmonizer?
    var presets = [Preset]()
    var favorites = [Int]()
    var presetIx: Int = 0
    
    //MARK: preset save/load
    
    func stateURL() -> URL
    {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURL = DocumentsDirectory.appendingPathComponent("state")
        return ArchiveURL
    }
    
    func saveState()
    {
        let f = stateURL()
        let s = self.audioUnit!.fullState
        NSKeyedArchiver.archiveRootObject(s as Any, toFile: f.path)
    }
    
    func restoreState()
    {
        loadPresets()
        
        let f = stateURL()
        let s = NSKeyedUnarchiver.unarchiveObject(withFile: f.path) as? [String: Any]
        if (s != nil)
        {
            self.audioUnit!.fullState = s
        }
        else
        {
        }
    }
    
    func presetURL() -> URL
    {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        return DocumentsDirectory.appendingPathComponent("presets")
    }
    
    func storePresets()
    {
        let obj = ["presets": presets,"presetIx": presetIx, "favorites": favorites] as [String : Any]
        
        NSKeyedArchiver.archiveRootObject(obj, toFile: presetURL().path)
    }
    
    func getPreset() -> [String: Any]?
    {
        return audioUnit!.fullState
    }
    
    func writePreset(name: String, ix: Int)
    {
        if (ix < 0 || ix > presets.count - 1)
        {
            return
        }
        
        if (presets[ix].isFactory)
        {
            return
        }
        presets[ix].name = name
        presets[ix].data = getPreset()
        
        presetIx = ix
        
        storePresets()
    }
    
    func loadPresets()
    {
        let p = NSKeyedUnarchiver.unarchiveObject(withFile: presetURL().path) as? [String : Any]
        if (p != nil)
        {
            presets = p!["presets"] as! [Preset]
            presetIx = p!["presetIx"] as! Int
            favorites = p!["favorites"] as! [Int]
            
            if (favorites.count == 0)
            {
                for k in 0...5 {
                    favorites.append(k)
                }
            }
        }
        else
        {
            generatePresets()
            storePresets()
        }
    }
    
    func isPresetModified() -> Bool
    {
        return false
    }
    
    func generatePresets()
    {
        for k in 0...(audioUnit!.factoryPresets?.count)!-1 {
            let p = (audioUnit!.factoryPresets?[k])!
            presets.append(Preset(name:p.name, data: nil, isFactory: true))
            
            if (p.name == audioUnit!.currentPreset?.name)
            {
                presetIx = k
            }
        }
        
        if (favorites.count == 0)
        {
            for k in 0...5 {
                favorites.append(k)
            }
        }
        
        presets.append(Preset(name: "New Preset", data: nil, isFactory: false))
    }
    
    func selectPreset(preset: Int)
    {
        if (preset < presets.count && preset >= 0) {
            presetIx = preset
            let p = presets[preset]
            if (p.isFactory)
            {
                self.audioUnit!.currentPreset = self.audioUnit!.factoryPresets?[preset]
            }
            else
            {
                self.audioUnit!.fullState = p.data as? [String: Any]
            }
            
            storePresets() // NOTE: we have to store to keep index
        }
    }
    
    func canIncrement() -> Bool
    {
        return (presetIx < presets.count - 1)
    }
    func canDecrement() -> Bool
    {
        return (presetIx > 0)
    }
    
    func currentPreset() -> Preset
    {
        return presets[presetIx]
    }
    
    func incrementPreset(inc: Int)
    {
        if (inc < 0 && presetIx > 0)
        {
            selectPreset(preset: presetIx - 1)
        }
        if (inc > 0 && presetIx < presets.count - 1)
        {
            selectPreset(preset: presetIx + 1)
        }
    }
    
    func appendPreset()
    {
        presets.append(Preset(name: "New Preset", data: nil, isFactory: false))
    }
}
