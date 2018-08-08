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
    {
        didSet {
            for f in (audioUnit?.fields())!
            {
                fields.append(f as! String)
            }
        }
    }
    
    var defaults: UserDefaults? = nil
    
    public var presetIx: Int {
        set (new) {
            var val = new
            if (val < 0) { val = 0 }
            if (val >= presets.count) { val = presets.count-1 }
            defaults?.set(val, forKey: "presetIndex")
        }
        get {
            var res = defaults?.integer(forKey: "presetIndex")
            if (res == nil)
            {
                defaults?.set(0, forKey: "presetIndex")
                res = 0
            }
            return res!
        }
    }
    
    var presets = [Preset]()
    var favorites = [Int]()
    //var presetIx: Int = 0
    
    var fields: [String] = []
    
    
    override init() {
        super.init()
        
        defaults = UserDefaults(suiteName: "group.harmonizr.extension")
    }
    
    //MARK: preset save/load
    
    func stateURL() -> URL
    {
        let DocumentsDirectory = FileManager().containerURL(forSecurityApplicationGroupIdentifier: "group.harmonizr.extension")
//        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let ArchiveURL = DocumentsDirectory?.appendingPathComponent("state")
        return ArchiveURL!
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
        let DocumentsDirectory = FileManager().containerURL(forSecurityApplicationGroupIdentifier: "group.harmonizr.extension")
        //let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        return DocumentsDirectory!.appendingPathComponent("presets")
    }
    
    func getPreset() -> Data
    {
        let state: NSMutableDictionary = [:]
        
        for key in fields {
            let p = (audioUnit!.parameterTree?.value(forKey: key) as? AUParameter)?.value
            state[key] = p
        }
        
        var js: Data? = nil
        print(state)
        do {
            js = try JSONSerialization.data(withJSONObject: state, options: [])
            print(String(data: js!, encoding: .utf8) as Any)
        }
        catch {
            print("Failed to encode to json")
        }
        return js!
        //return audioUnit!.fullState
    }
    
    func setPreset(_ data: Data)
    {
        var state: NSMutableDictionary? = nil
        do {
            state = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? NSMutableDictionary
        }
        catch {
            return
        }
        for key in fields {
            let p = audioUnit!.parameterTree?.value(forKey: key) as? AUParameter
            p?.value = state![key] as! Float
        }
        
        //audioUnit!.fullState = data
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
    
    func storePresets()
    {
        let obj = ["presets": presets,"presetIx": presetIx, "favorites": favorites] as [String : Any]
        
        NSKeyedArchiver.archiveRootObject(obj, toFile: presetURL().path)
    }
    
    func loadPresets()
    {
        let p = NSKeyedUnarchiver.unarchiveObject(withFile: presetURL().path) as? [String : Any]
        if (p != nil)
        {
            presets = p!["presets"] as! [Preset]
            //presetIx = p!["presetIx"] as! Int
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
                p.data = getPreset()
            }
            else
            {
                setPreset(p.data as! Data)
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
