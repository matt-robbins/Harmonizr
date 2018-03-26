/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the FilterDemo audio unit. Manages the interactions between a FilterView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit
import os

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


public class HarmonizerViewController: AUViewController, HarmonizerViewDelegate, VoicesViewDelegate {
    // MARK: Properties

    @IBOutlet weak var harmonizerView: HarmonizerView!
    @IBOutlet weak var voicesView: HarmonizerVoicesView!
    
    @IBOutlet weak var midiButton: HarmButton!
    @IBOutlet weak var autoButton: HarmButton!
    
    @IBOutlet weak var presetPrevButton: HarmButton!
    @IBOutlet weak var presetNextButton: HarmButton!
    @IBOutlet weak var presetEditButton: HarmButton!
    @IBOutlet weak var presetLabel: UILabel!
    
    @IBOutlet var presetFavorites: [HarmButton]!
    
    /*
		When this view controller is instantiated within the app, its
        audio unit is created independently, and passed to the view controller here.
	*/
    public var audioUnit: AUv3Harmonizer? {
        didSet {
			/*
				We may be on a dispatch worker queue processing an XPC request at 
                this time, and quite possibly the main queue is busy creating the 
                view. To be thread-safe, dispatch onto the main queue.
				
				It's also possible that we are already on the main queue, so to
                protect against deadlock in that case, dispatch asynchronously.
			*/
			DispatchQueue.main.async {
				if self.isViewLoaded {
					self.connectViewWithAU()
				}
			}
        }
    }
	
    var keycenterParameter: AUParameter?
    var inversionParameter: AUParameter?
    var nvoicesParameter: AUParameter?
    var autoParameter: AUParameter?
    var midiParameter: AUParameter?
    var triadParameter: AUParameter?
    var bypassParameter: AUParameter?
    var speedParameter: AUParameter?
    var gainParameter: AUParameter?
	var parameterObserverToken: AUParameterObserverToken?
    
    var configController: ConfigViewController?
    var saveController: SavePresetViewController?
    
    var presets = [Preset]()
    var presetIx: Int = 0
    var presetModified: Bool = false {
        didSet {

        }
    }

    var timer = Timer()
    
    func auPoller(T: Float){
        // Scheduling timer to Call the timerFunction
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
    }
    
    func timerFunction()
    {
        guard let audioUnit = audioUnit else { return }
        harmonizerView.setSelectedNote(audioUnit.getCurrentNote())
        // update visible keycenter based on computed value from midi
        harmonizerView.setSelectedKeycenter(audioUnit.getCurrentKeycenter())
        return
    }

	public override func viewDidLoad() {
		super.viewDidLoad()
		
		// Respond to changes in the filterView (frequency and/or response changes).
        harmonizerView.delegate = self
        voicesView.delegate = self
        
        auPoller(T: 0.1)
		configController = self.storyboard?.instantiateViewController(withIdentifier: "configView") as? ConfigViewController
        let _: UIView = configController!.view
        
        saveController = self.storyboard?.instantiateViewController(withIdentifier: "savePresetView") as? SavePresetViewController
        
        saveController?.vc = self
        guard audioUnit != nil else { return }
        
        connectViewWithAU()
        
	}
    
    //MARK: VoicesViewDelegate
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeInversion inversion: Float)
    {
        inversionParameter?.value = inversion
        presetModified = true
    }
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeNvoices voices: Float)
    {
        nvoicesParameter?.value = voices
        presetModified = true
    }
    
    
    //MARK: HarmonizerViewDelegate
    
    func harmonizerView(_ view: HarmonizerView, didChangeKeycenter keycenter: Float)
    {
        keycenterParameter?.value = keycenter
    }
    
    func harmonizerViewGetPitch(_ view: HarmonizerView) -> Float {
        return audioUnit!.getCurrentNote()
    }
    
    func harmonizerViewGetKeycenter(_ view: HarmonizerView) -> Float {
        return keycenterParameter!.value
    }
    
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
        let obj = ["presets": presets,"presetIx": presetIx] as [String : Any]
        NSKeyedArchiver.archiveRootObject(obj, toFile: presetURL().path)
    }
    
    func loadPresets()
    {
        let p = NSKeyedUnarchiver.unarchiveObject(withFile: presetURL().path) as? [String : Any]
        if (p != nil)
        {
            presets = p!["presets"] as! [Preset]
            presetIx = p!["presetIx"] as! Int
//            presets = (p!["presets"] as? [Preset])!
//            presetIx = (p!["presetIx"] as? Int)!
            //harmonizerView.preset = presets[presetIx].name
            //harmonizerView(harmonizerView, didChangePreset: presetIx)
        }
        else
        {
            generatePresets()
            storePresets()
        }
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
        
        for k in 0...10
        {
            presets.append(Preset(name: "User \(k)", data: nil, isFactory: false))
        }
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
            
            storePresets()
            presetModified = false
            presetLabel.text = p.name
        }
        
        syncView()
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
    
	/*
		We can't assume anything about whether the view or the AU is created first.
		This gets called when either is being created and the other has already 
        been created.
	*/
	func connectViewWithAU() {
        
        guard let paramTree = audioUnit?.parameterTree else { return }
        
        keycenterParameter = paramTree.value(forKey: "keycenter") as? AUParameter
        inversionParameter = paramTree.value(forKey: "inversion") as? AUParameter
        nvoicesParameter = paramTree.value(forKey: "nvoices") as? AUParameter
        autoParameter = paramTree.value(forKey: "auto") as? AUParameter
        midiParameter = paramTree.value(forKey: "midi") as? AUParameter
        triadParameter = paramTree.value(forKey: "triad") as? AUParameter
        bypassParameter = paramTree.value(forKey: "bypass") as? AUParameter
        speedParameter = paramTree.value(forKey: "speed") as? AUParameter
        gainParameter = paramTree.value(forKey: "h_gain") as? AUParameter
        
        self.restoreState()
        
        var pendingRequestWorkItem: DispatchWorkItem?
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            pendingRequestWorkItem?.cancel()
            let requestWorkItem = DispatchWorkItem { [weak self] in self?.saveState() }
            pendingRequestWorkItem = requestWorkItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250),
                                          execute: requestWorkItem)
		})
        
        configController!.refresh()
        
        //harmonizerView.presets = (audioUnit?.factoryPresets)!
        //harmonizerView.preset = audioUnit!.currentPreset?.name
        
        syncView()
	}
    
    private func syncView()
    {
        midiButton.isSelected = (midiParameter!.value == 1)
        autoButton.isSelected = (autoParameter!.value == 1)
        
        voicesView.setSelectedVoices(Int(nvoicesParameter!.value), inversion: Int(inversionParameter!.value))
        
        harmonizerView.setSelectedKeycenter(keycenterParameter!.value)
        
        presetPrevButton.isEnabled = (presetIx > 0)
        presetNextButton.isEnabled = (presetIx < presets.count - 1)
        
        presetLabel.text = presets[presetIx].name
    }
    
    //MARK: Actions
    
    @IBAction func toggleAuto(_ sender: Any) {
        autoParameter!.value = autoParameter!.value == 0 ? 1 : 0
        autoButton.isSelected = autoParameter!.value == 1
    }
    
    @IBAction func toggleMidi(_ sender: Any) {
        midiParameter!.value = midiParameter!.value == 0 ? 1 : 0
        midiButton.isSelected = midiParameter!.value == 1
    }
    
    @IBAction func presetPrev(_ sender: Any) {
        incrementPreset(inc: -1)
    }
    
    @IBAction func presetNext(_ sender: Any) {
        incrementPreset(inc: 1)
    }
    
    
    @IBAction func setPreset(_ sender: HarmButton) {
        for b in presetFavorites {
            if (b === sender)
            {
                selectPreset(preset: b.keycenter)
            }
        }
    }
    
    @IBAction func presetConf(_ sender: HarmButton) {
        self.configController!.audioUnit = self.audioUnit
        sender.isSelected = true
        
        //performSegue(withIdentifier: "configurePreset", sender: self)
        //
        self.present(self.configController!, animated:true, completion:
            {
                self.presetModified=true
                self.configController!.refresh()
                sender.isSelected = false
        })
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        guard let button = sender.view as! HarmButton?
        else
        {
            return
        }
        print(button.keycenter)
        
        performSegue(withIdentifier: "fastPreset", sender:self)
    }
    
}
