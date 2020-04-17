/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the FilterDemo audio unit. Manages the interactions between a FilterView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit
import os

//public var globalAudioUnit: AUv3Harmonizer?


class HarmonizerViewController: AUViewController, HarmonizerViewDelegate, VoicesViewDelegate, KeyboardViewDelegate, HarmonizerDelegate {
    
    // MARK: Properties

    @IBOutlet weak var harmonizerView: HarmonizerView!
    @IBOutlet weak var voicesView: HarmonizerVoicesView!
    
    @IBOutlet weak var keyboardView: KeyboardView!
    @IBOutlet weak var recordButton: HarmButton!
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var keyboardStack: UIStackView!
    @IBOutlet weak var midiButton: HarmButton!
    @IBOutlet weak var videoButton: HarmButton!
    @IBOutlet weak var dryButton: HarmButton!
    @IBOutlet weak var presetButton: LabelButton!
    
    @IBOutlet weak var kbdLinkButton: HarmButton!
    @IBOutlet weak var kbdOctPlusButton: UIButton!
    @IBOutlet weak var kbdOctMinusButton: UIButton!
    
    @IBOutlet weak var presetPrevButton: HarmButton!
    @IBOutlet weak var presetNextButton: HarmButton!
    @IBOutlet weak var presetEditButton: HarmButton!
    @IBOutlet weak var presetLabel: UILabel!
    
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet var presetFavorites: [HarmButton]!
    
    private var noteBlock: AUScheduleMIDIEventBlock!
    
    /*
		When this view controller is instantiated within the app, its
        audio unit is created independently, and passed to the view controller here.
	*/
    
    public var interfaceDelegate: InterfaceDelegate?
    
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
            
            globalAudioUnit = audioUnit
        }
    }
    	
    var keycenterParameter: AUParameter?
    var inversionParameter: AUParameter?
    var nvoicesParameter: AUParameter?
    var autoParameter: AUParameter?
    var midiParameter: AUParameter?
    var midiLinkParameter: AUParameter?
    var midiPCParameter: AUParameter?
    var triadParameter: AUParameter?
    var bypassParameter: AUParameter?
    var speedParameter: AUParameter?
    var hgainParameter: AUParameter?
    var vgainParameter: AUParameter?
	var parameterObserverToken: AUParameterObserverToken?
    
    var intervals = [AUParameter]()
    
    var configController: ConfigNavigationController?
    var saveController: PresetSaveViewController?
    var presetController: PresetController?
    
    var presetState: Data?
    
    var presetModified: Bool = false {
        didSet {
            //presetLabel.textColor = (presetModified == true) ? self.view.tintColor : UIColor.lightGray
            presetButton.isModified = presetModified
        }
    }

    var updater:CADisplayLink? = nil
    
    func auPoller(T: Float){
        // Scheduling timer to Call the timerFunction
//        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
        
        updater = CADisplayLink(target: self, selector: #selector(timerFunction))
        updater?.add(to: .current, forMode: .defaultRunLoopMode)
        updater?.isPaused = false
    }
    
    @objc func timerFunction()
    {
        guard let audioUnit = audioUnit else { return }
        
        let note = audioUnit.getCurrentNote()
        
        harmonizerView.setSelectedNote(note)
        
        let notes = audioUnit.getNotes()
        var int_notes: [Int] = [Int]()
        
        for n in notes! {
            int_notes.append((n as? Int)!)
        }
        
        let keys = audioUnit.getKeysDown()!
        
        for k in 0 ..< keys.count
        {
            keyboardView!.keys[k].isSelected = (keys[k] as! Bool)
        }

        keyboardView.setCurrentNote(int_notes)
        // update visible keycenter based on computed value from midi
        harmonizerView.setSelectedKeycenter(audioUnit.getCurrentKeycenter())
        return
    }

	override func viewDidLoad() {
		super.viewDidLoad()
        
//        let theme = ThemeManager.currentTheme()
//        ThemeManager.applyTheme(theme)
//        
//        for view in self.view.subviews as [UIView] {
//            if let btn = view as? UIButton {
//                btn.titleLabel?.adjustsFontSizeToFitWidth = true
//            }
//        }
		
		// Respond to changes in the filterView (frequency and/or response changes).
        harmonizerView.delegate = self
        voicesView.delegate = self
        keyboardView.delegate = self
        
        keyboardView.keyOffset = 28
        
        presetController = PresetController()
        
        auPoller(T: 0.05)
		//configController = self.storyboard?.instantiateViewController(withIdentifier: "detailsNavigator") as? ConfigNavigationController
        
        saveController = self.storyboard?.instantiateViewController(withIdentifier: "saveController") as? PresetSaveViewController
        
        //configController!.viewDelegate = self
        saveController!.presetController = presetController
        
        videoButton.isEnabled = (interfaceDelegate != nil)
        
        let midiImage = KeyboardView()
        midiImage.isUserInteractionEnabled = false
        midiImage.keyOffset = 14
        midiImage.n_visible = 3
        midiImage.labels = false
        midiImage.translatesAutoresizingMaskIntoConstraints = false
        midiButton.addSubview(midiImage)
        
        midiImage.centerXAnchor.constraint(equalTo: midiButton.centerXAnchor).isActive = true
        midiImage.centerYAnchor.constraint(equalTo: midiButton.centerYAnchor).isActive = true
        midiImage.widthAnchor.constraint(equalTo: midiButton.widthAnchor, multiplier: 0.66).isActive = true
        midiImage.heightAnchor.constraint(equalTo: midiButton.heightAnchor, multiplier: 0.66).isActive = true
        
        //midiButton.bringSubview(toFront: midiImage)
        //let _: UIView = configController!.view
        
        //configController!.presetController = presetController
        
//        self.addChildViewController(self.configController!)
//
//        self.containerView.addSubview(configController!.view)
//
//        configController!.didMove(toParentViewController: self)
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appResigned), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        
        connectViewWithAU()
	}
    
    @objc private func appResigned()
    {
        keyboardView.allNotesOff()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        let icon = (defaults?.bool(forKey: "recordVideo") ?? false) ? "video.fill" : "circle.fill"
        
        if #available(iOSApplicationExtension 13.0, *) {
            videoButton!.setImage(UIImage(systemName: icon), for: .normal)
        } else {
            // Fallback on earlier versions
        }
        syncView()
    }
    
    func getVideoView() -> UIView
    {
        return self.videoView
    }
    
    func checkPresetModified() {
        presetState = presetController!.getPreset()
        
        guard let d = presetController!.currentPreset()?.data else {
            presetModified = true
            return
        }
        
        presetModified = !(presetState == d)
    }
    
    //MARK: VoicesViewDelegate
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeInversion inversion: Float)
    {
        inversionParameter?.value = inversion
        checkPresetModified()
    }
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeNvoices voices: Float)
    {
        nvoicesParameter?.value = voices
        checkPresetModified()
    }
    
    //MARK: KeyboardViewDelegate
    
    func keyboardView(_ view: KeyboardView, noteOn note: Int) {
        audioUnit?.addMidiNote(Int32(note), vel: 80)
    }
    
    func keyboardView(_ view: KeyboardView, noteOff note: Int) {
        audioUnit?.remMidiNote(Int32(note))
    }
    
    //MARK: HarmonizerViewDelegate
    
    func harmonizerView(_ view: HarmonizerView, didChangeKeycenter keycenter: Float)
    {
        keycenterParameter?.value = keycenter
    }
    
    func harmonizerView(_ view: HarmonizerView, touchIsDown touch: Bool)
    {
        speedParameter!.value = touch ? 0.1: 1.0
    }
    
    func harmonizerViewGetPitch(_ view: HarmonizerView) -> Float {
        return audioUnit!.getCurrentNote()
    }
    
    func harmonizerViewGetKeycenter(_ view: HarmonizerView) -> Float {
        return keycenterParameter!.value
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
        midiLinkParameter = paramTree.value(forKey: "midi_link") as? AUParameter
        midiParameter = paramTree.value(forKey: "midi_rx_pc") as? AUParameter
        triadParameter = paramTree.value(forKey: "triad") as? AUParameter
        bypassParameter = paramTree.value(forKey: "bypass") as? AUParameter
        speedParameter = paramTree.value(forKey: "speed") as? AUParameter
        hgainParameter = paramTree.value(forKey: "h_gain") as? AUParameter
        vgainParameter = paramTree.value(forKey: "v_gain") as? AUParameter
        print(hgainParameter!.value)
        presetController!.audioUnit = audioUnit
        presetController!.restoreState()
        presetController!.loadPresets()
        print("index = \(presetController!.presetIx)")
        
        
        //presetState = presetController!.getPreset()
        
        var pendingRequestWorkItem: DispatchWorkItem?
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            pendingRequestWorkItem?.cancel()
            let requestWorkItem = DispatchWorkItem { [weak self] in self?.presetController?.saveState() }
            pendingRequestWorkItem = requestWorkItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250),
                                          execute: requestWorkItem)
		})
        
        audioUnit?.delegate = self
        //configController!.audioUnit = self.audioUnit
//        configController!.presetController = self.presetController
//
//        configController!.refresh()
        
        let theNoteBlock = audioUnit!.scheduleMIDIEventBlock
        
        noteBlock = theNoteBlock
        
        syncView()
	}
    
    func syncView()
    {
        if (audioUnit != nil)
        {
            midiButton.isSelected = (midiParameter!.value == 1)
            dryButton.isSelected = (hgainParameter!.value == 0)
            kbdLinkButton.isSelected = (midiLinkParameter!.value == 1)
            
            enableKeyboard(midiButton.isSelected)
            
            //print(audioUnit?.getCurrentInversion())
            voicesView.autoTuneVoice1 = (autoParameter?.value ?? 0.0) > 0.5
            voicesView.setSelectedVoices(Int(audioUnit?.getCurrentNumVoices() ?? 0), inversion: Int(audioUnit?.getCurrentInversion() ?? 0))
            
            voicesView.alpha = dryButton.isSelected ? 0.5 : 1.0
            
            harmonizerView.setSelectedKeycenter(keycenterParameter!.value)
        }
        
        if ((presetController) != nil)
        {
            presetPrevButton.isEnabled = (presetController!.canDecrement())
            presetNextButton.isEnabled = (presetController!.canIncrement())
            
            //presetLabel.text = presetController!.currentPreset().name
            //presetButton.titleLabel?.text =
            presetButton.isModified = presetModified
            
            if let preset = presetController!.currentPreset()
            {
                presetButton.titleText = preset.name!
            }
            else
            {
                presetButton.titleText = "(no preset)"
            }
            
            for k in 0...presetFavorites.count-1
            {
                presetFavorites[k].isSelected = (presetFavorites[k].tag == presetController!.presetIx)
            }
            
            checkPresetModified()
        }
        
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        let kb = defaults?.bool(forKey: "showMidiKeyboard")
        if (kb != nil)
        {
            keyboardStack.isHidden = !(kb!)
        }
    }
    
    func enableKeyboard(_ enable: Bool)
    {
        UIView.animate(withDuration: 0.3) {
            self.keyboardView.isUserInteractionEnabled = enable
            self.keyboardView.layer.opacity = enable ? 1.0 : 0.3
        }
    }
    
    //MARK: Actions
    
//    @IBAction func toggleAuto(_ sender: Any) {
//        autoParameter!.value = autoParameter!.value == 0 ? 1 : 0
//        autoButton.isSelected = autoParameter!.value == 1
//        voicesView.autoTuneVoice1 = autoParameter!.value == 1
//        checkPresetModified()
//    }
    
    @IBAction func toggleMidi(_ sender: Any) {
        midiParameter!.value = midiParameter!.value == 0 ? 1 : 0
        midiButton.isSelected = midiParameter!.value == 1
        enableKeyboard(self.midiButton.isSelected)
    }
    
    @IBAction func toggleLink(_ sender: Any) {
        midiLinkParameter!.value = midiLinkParameter!.value == 0 ? 1 : 0
        kbdLinkButton.isSelected = midiLinkParameter!.value == 1
    }
    
    @IBAction func toggleDry(_ sender: Any) {
        
        dryButton.isSelected = !dryButton.isSelected
        hgainParameter!.value = dryButton.isSelected ? 0 : 1
        voicesView.alpha = dryButton.isSelected ? 0.5 : 1
        
        checkPresetModified()
        //print(hgainParameter!.value)
        
    }
    
    @IBAction func savePreset(_ sender: HarmButton) {
        if (presetModified)
        {
            performSegue(withIdentifier: "saveToPreset", sender:sender)
        }
        else
        {
            performSegue(withIdentifier: "presetList", sender:sender)
        }
    }
    
    
    @IBAction func octaveUp(_ sender: Any) {
        keyboardView.keyShift(7)
    }
    @IBAction func OctaveDown(_ sender: Any) {
        keyboardView.keyShift(-7)
    }
    
    @IBAction func presetPrev(_ sender: Any) {
        presetController?.incrementPreset(inc: -1)
        presetModified = false
        syncView()
    }
    
    @IBAction func presetNext(_ sender: Any) {
        presetController?.incrementPreset(inc: 1)
        presetModified = false
        syncView()
    }
    
    @IBAction func toggleRecording(_ sender: Any) {
        
        if (videoButton.tag == 1)
        {
            videoButton.tag = 0
            let vc = interfaceDelegate?.getFilesViewController()
            if (vc != nil)
            {
                self.show(vc!, sender: self)
            }
            if #available(iOSApplicationExtension 13.0, *) {
                videoButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
                videoButton.tintColor = UIColor.red
            } else {
                // Fallback on earlier versions
            }
            return
        }
        
        
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1
        animation.toValue = 0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        let iv = videoButton.imageView
        iv?.layer.removeAllAnimations()
        
        let rec = interfaceDelegate?.didToggleRecording() ?? .idle
        print(rec)
        
        switch (rec) {
        case .standby:
            iv?.layer.add(animation,forKey:"borderPulse")
        case .recording:
            if #available(iOSApplicationExtension 13.0, *) {
                videoButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
            } else {
                // Fallback on earlier versions
            }
        case .idle:
            if #available(iOSApplicationExtension 13.0, *) {
                videoButton.setImage(UIImage(systemName: "video.fill"), for: .normal)
            } else {
                // Fallback on earlier versions
            }
        }
        
        if (interfaceDelegate?.recordingsAvailable() ?? false)
        {
            if #available(iOSApplicationExtension 13.0, *) {
                videoButton.setImage(UIImage(systemName: "folder"), for: .normal)
                videoButton.tintColor = UIColor.yellow
            } else {
                // Fallback on earlier versions
            }
            videoButton.tag = 1
        }

    }
    
    @IBAction func setPreset(_ sender: HarmButton) {
        for b in presetFavorites {
            if (b === sender)
            {
                self.presetController?.loadPresets()
                let ix = b.keycenter
                
                self.presetController?.selectPreset(preset: ix)
                print(presetController!.presetIx)
                presetModified = false
                syncView()
            }
        }
    }
    
    func programChange(_ program: Int32) {
//        if ((midiPCParameter?.value ?? 0) < AUValue(1.0))
//        {
//            return
//        }
        self.presetController?.selectPreset(preset: Int(program))
        syncView()
    }
    
    func ccValue(_ value: Int32, forCc cc: Int32) {
        syncView()
    }
    
    func ShowMainView() {
        
        self.containerView.isHidden = true
        self.mainView.isHidden = false
        self.mainView.alpha = 1.0
        self.syncView()
        
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        guard let button = sender.view as! HarmButton?
        else
        {
            return
        }
        
        if (sender.state == .began)
        {
            performSegue(withIdentifier: "fastPreset", sender:button)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if segue.identifier == "fastPreset" {
            if let destinationVC = segue.destination as? PresetFavoriteViewController {
                destinationVC.favIx = ((sender as? HarmButton)?.keycenter)!
                destinationVC.doneFcn = {
                    print("hi!")
                    self.presetController!.loadPresets()
                    self.syncView()
                }
            }
        }
        else if segue.identifier == "saveToPreset" {
            if let destinationVC = segue.destination as? PresetSaveViewController {
                destinationVC.presetController = presetController
            }
        }
        else if segue.identifier == "presetList" {
            if let destinationVC = segue.destination as? PresetListViewController {
                destinationVC.presetController = presetController
            }
        }
        
        else if segue.identifier == "showSettings" {
            if let destinationVC = segue.destination as? SettingsViewController {
                destinationVC.reverbAudioUnit = interfaceDelegate?.getReverbUnit()
                destinationVC.interfaceDelegate = interfaceDelegate
            }
        }
    }
    
}
