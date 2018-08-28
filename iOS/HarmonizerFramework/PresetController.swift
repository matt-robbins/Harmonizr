//
//  PresetController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 3/26/18.
//

import UIKit
import CoreData

class OldPreset: NSObject, NSCoding {
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
    
    var defaults: UserDefaults?
    var moc: NSManagedObjectContext? = nil
    
    public var presetIx: Int {
        set (new) {
            var val = new
            if (val < 0) { val = 0 }
            if (val >= presets.count) { val = presets.count-1 }
            defaults?.set(val, forKey: "presetIndex")
        }
        get {
            if (defaults == nil)
            {
                return -1
            }
            var res = defaults?.integer(forKey: "presetIndex")
            if (res == nil)
            {
                defaults?.set(0, forKey: "presetIndex")
                res = -2
            }
            return res!
        }
    }
    
    var presets = [Preset]()
    var favorites = [Int]()
    
    var fields: [String] = []
    
    override init() {
        super.init()
        
        defaults = UserDefaults()
        
        if (moc == nil)
        {
            guard let modelURL = Bundle.main.url(forResource: "PresetModel", withExtension: "momd") else {
                fatalError("failed to find data model")
            }
            
            //guard let mom = NSManagedObjectModel.mergedModel(from: nil) else {
            guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
                fatalError("Failed to create model!")
            }
            
            let psc = NSPersistentStoreCoordinator(managedObjectModel: mom)
            
            let dirURL = FileManager().containerURL(forSecurityApplicationGroupIdentifier: "group.harmonizr.extension")
            let fileURL = URL(string: "Presets.db", relativeTo: dirURL)
            
            let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
            do {
                try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: fileURL, options: options)
            } catch {
                fatalError("Error configuring persistent store: \(error)")
            }
            
            moc = NSManagedObjectContext(concurrencyType:.mainQueueConcurrencyType)
            moc!.persistentStoreCoordinator = psc
        }
    }
    
    //MARK: preset save/load
    
    func stateURL() -> URL
    {
//        let DocumentsDirectory = FileManager().containerURL()
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
        
        //selectPreset(preset: presetIx)
        let f = stateURL()
        let s = NSKeyedUnarchiver.unarchiveObject(withFile: f.path) as? [String: Any]
        if (s != nil)
        {
            self.audioUnit!.fullState = s
        }
    }
    
    func saveMoc() {
        do {
            try moc!.save()
        }
        catch let error as NSError {
            print("oopsy! \(error)")
        }
    }
    
    func getPreset() -> Data
    {
        let state: NSMutableDictionary = [:]
        
        for key in fields {
            let p = (audioUnit!.parameterTree?.value(forKey: key) as? AUParameter)?.value
            state[key] = p
        }
        
        var js: Data? = nil
        do {
            js = try JSONSerialization.data(withJSONObject: state, options: [])
        }
        catch {
            print("Failed to encode to json")
        }
        
        return js!
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
    }
    
    func updatePreset(name: String, ix: Int)
    {
        if (ix < 0 || ix > presets.count - 1)
        {
            return
        }
        
        if (presets[ix].factoryId >= 0)
        {
            return
        }
        presets[ix].name = name
        presets[ix].data = getPreset()
        
        presetIx = ix
        
        storePresets()
        loadPresets()
    }
    
    func storePresets()
    {
        for ix in 0...presets.count-1 {
            presets[ix].index = Int32(ix)
        }
        
        saveMoc()
    }
    
    func loadPresets()
    {
        let managedContext = moc!
        
        let fetchRequest = NSFetchRequest<Preset>(entityName: "Preset")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "index", ascending: true)]
        
        do {
            presets = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("failed to fetch. \(error), \(error.userInfo)")
        }
        
        //selectPreset(preset: presetIx)
        
        if (presets.count == 0)
        {
            generatePresets()
            loadOldPresets()
            storePresets()
        }
        
        updateFactoryPresets()
    }
    
    func updateFactoryPresets()
    {
        let fetchRequest = NSFetchRequest<Preset>(entityName: "Preset")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "factoryId", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "factoryId >= 0")
        
        var presets = [Preset]()
        
        do {
            presets = try moc!.fetch(fetchRequest)
        } catch let error as NSError {
            print("failed to fetch. \(error), \(error.userInfo)")
        }
        
        if (presets.count != audioUnit!.factoryPresets?.count)
        {
            for p in self.presets {
                if (p.factoryId >= 0) {
                    moc!.delete(p)
                    self.presets.remove(at: self.presets.index(of: p)!)
                }
            }
            
            saveMoc()
            generatePresets()
        }
    }
    
    func loadOldPresets()
    {
        let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        let presetURL = DocumentsDirectory.appendingPathComponent("presets")
        NSKeyedArchiver.setClassName("HarmonizerFramework.Preset", for: OldPreset.self)
        NSKeyedUnarchiver.setClass(OldPreset.self, forClassName: "HarmonizerFramework.Preset")
        let p = NSKeyedUnarchiver.unarchiveObject(withFile: presetURL.path) as? [String : Any]
        if (p != nil)
        {
            let oldPresets = p!["presets"] as! [OldPreset]
            
            for op in oldPresets {
                if (!op.isFactory && op.data != nil)
                {
                    //print(op.data)
                    self.audioUnit!.fullState = op.data as? [String: Any]
                    self.appendPreset(name: op.name!, insert: false)
                }
            }
            
            do {
                try FileManager().removeItem(at: presetURL)
            }
            catch
            {
                print("failed to delete old presets")
            }
        }
    }
    
    func isPresetModified() -> Bool
    {
        return false
    }
    
    func getMaxId()
    {
        
    }
    
    func appendPreset(name: String, insert: Bool = true)
    {
       // presets.append(Preset(name: "New Preset", data: nil, factoryId: -1))
        
        let fetchRequest = NSFetchRequest<Preset>(entityName: "Preset")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        var maxId = 0
        do {
            let persons = try moc!.fetch(fetchRequest)
            maxId = Int((persons.first?.id)!)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        let entity = NSEntityDescription.entity(forEntityName: "Preset", in: moc!)!
        
        let p = Preset(entity: entity, insertInto: moc!)
        p.name = name
        p.id = Int32(maxId)
        p.data = getPreset()
        p.factoryId = Int32(-1)
        
        if (insert)
        {
            presets.insert(p, at: presetIx)
        }
        else {
            presets.append(p)
        }
        
        storePresets()
        
        loadPresets()
        if (insert)
        {
            presetIx = presets.index(of: p)!
        }
    }
    
    func generatePresets()
    {
        for k in 0...(audioUnit!.factoryPresets?.count)!-1 {
            let fp = (audioUnit!.factoryPresets?[k])!
            
            let entity = NSEntityDescription.entity(forEntityName: "Preset", in: moc!)!
            
            let p = Preset(entity: entity, insertInto: moc!)
            p.name = fp.name
            p.id = Int32(presets.count)
            p.data = nil
            p.factoryId = Int32(k)
            
            do {
                try moc!.save()
                presets.append(p)
                //presetIx = max_id
            }
            catch let error as NSError {
                print("Failed to save. \(error), \(error.userInfo)")
            }
            
            if (p.name == audioUnit!.currentPreset?.name)
            {
                presetIx = k
            }
        }
    }
    
    func selectPreset(preset: Int)
    {
        if (preset < presets.count && preset >= 0) {
            presetIx = preset
            let p = presets[preset]
            if (p.factoryId >= 0)
            {
                let fp = self.audioUnit!.factoryPresets?[Int(p.factoryId)]
                
                self.audioUnit!.currentPreset = fp
                if (p.data == nil || p.data != getPreset() || p.name != fp?.name)
                {
                    p.data = getPreset()
                    p.name = fp?.name
                    storePresets()
                }
            }
            else
            {
                setPreset(p.data!)
            }
        }
    }
    
    func swap(src: Int, dst: Int)
    {
        let p = presets[presetIx]
        let tmp = presets.remove(at: src)
        presets.insert(tmp, at: dst)
        storePresets()
        selectPreset(preset: presets.index(of: p)!)
    }
    
    func delete(ix: Int)
    {
        moc!.delete(presets[ix])
        presets.remove(at: ix)
        storePresets()
        loadPresets()
        
        selectPreset(preset: presetIx)
    }
    
    func canIncrement() -> Bool
    {
        return (presetIx < presets.count - 1)
    }
    func canDecrement() -> Bool
    {
        return (presetIx > 0)
    }
    
    func currentPreset() -> Preset?
    {
        if (presetIx < presets.count && presetIx >= 0)
        {
            return presets[presetIx]
        }
        else
        {
            return nil
        }
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
}
