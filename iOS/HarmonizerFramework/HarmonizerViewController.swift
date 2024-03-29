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

public enum TutorialSection: CaseIterable {
    case none
    case presets
    case keycenter
    case voices
    case loop
    case keyboard
    case midi
    case record
}

class HarmonizerViewController: AUViewController, HarmonizerViewDelegate, VoicesViewDelegate, KeyboardViewDelegate, HarmonizerDelegate {
    
    // MARK: Properties

    @IBOutlet weak var harmonizerView: HarmonizerView!
    @IBOutlet weak var voicesView: HarmonizerVoicesView!
    
    @IBOutlet weak var keyboardView: KeyboardView!
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var presetsStack: UIStackView!
    @IBOutlet weak var loopStack: UIStackView!
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
    
    @IBOutlet weak var loopRecButton: HarmButton!
    @IBOutlet weak var loopStopButton: HarmButton!
    @IBOutlet weak var loopProgress: UIProgressView!
    
    private var noteBlock: AUScheduleMIDIEventBlock!
    
    private var midiReciever: MidiReceiver?
    
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
            
            //if (audioUnit?.componentDescription.componentType)
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
    
    var loopMode = 0
    
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
    
    @objc func updateDisplay()
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
        
        loopProgress.setProgress(audioUnit.getLoopPosition(), animated: false)
        //print(audioUnit.getLoopPosition())
        return
    }

	override func viewDidLoad() {
		super.viewDidLoad()
		
        harmonizerView.delegate = self
        voicesView.delegate = self
        keyboardView.delegate = self
        
        keyboardView.keyOffset = 28
        
        presetController = PresetController()
        
        updater = CADisplayLink(target: self, selector: #selector(updateDisplay))
        updater?.add(to: .current, forMode: .defaultRunLoopMode)
        updater?.isPaused = false
        
        saveController = self.storyboard?.instantiateViewController(withIdentifier: "saveController") as? PresetSaveViewController
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
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appResigned), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        
        connectViewWithAU()
        tutorial_highlight(.none)
	}
    
    @objc private func appResigned()
    {
        keyboardView.allNotesOff()
    }
    
    public func setButtonIcon(_ button: UIButton, named: String)
    {
        if #available(iOSApplicationExtension 18.0, *) {
            button.setImage(UIImage(named:named), for: .normal)
            return
        }
        let im = UIImage(named: named)?.withRenderingMode(.alwaysTemplate)
        let inset = button.frame.height/5
        button.setImage(im, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsetsMake(inset, inset, inset, inset)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       // let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        let icon = "circle.fill" // (defaults?.bool(forKey: "recordVideo") ?? false) ? "video.fill" : "circle.fill"
        
        setButtonIcon(videoButton!, named: icon)
        setButtonIcon(presetEditButton!, named: "gear")
        //setButtonIcon(midiButton, named: "midilogo")
        syncLoopButtons()
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
    
    public func tutorial_highlight(_ section: TutorialSection)
    {
        var dim = Float(0.2)
        
        var views = [TutorialSection: UIView?]()
        
        for section in TutorialSection.allCases
        {
            switch (section)
            {
            case .none:
                views[section] = nil
            case .keyboard:
                views[section] = keyboardStack
            case .keycenter:
                views[section] = harmonizerView
            case .loop:
                views[section] = loopStack
            case .presets:
                views[section] = presetsStack
            case .voices:
                views[section] = voicesView
            case .midi:
                views[section] = midiButton
            case .record:
                views[section] = videoButton
            }
        }
        
        if (section == .none)
        {
            dim = 1.0
        }
        UIView.animate(withDuration: 0.5, animations: {
            for v in views.values {
                v?.alpha = CGFloat(dim)
            }
            views[section]??.alpha = CGFloat(1.0)
        })
    }
    
    //MARK: VoicesViewDelegate
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeInversion inversion: Float)
    {
        let old = (inversionParameter?.value ?? 0)
        inversionParameter?.value = (inversion != old) ? inversion : old
        checkPresetModified()
    }
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeNvoices voices: Float)
    {
        let old = (nvoicesParameter?.value ?? 0)
        nvoicesParameter?.value = (voices != old) ? voices : old
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
        midiPCParameter = paramTree.value(forKey: "midi_rx_pc") as? AUParameter
        triadParameter = paramTree.value(forKey: "triad") as? AUParameter
        bypassParameter = paramTree.value(forKey: "bypass") as? AUParameter
        speedParameter = paramTree.value(forKey: "speed") as? AUParameter
        hgainParameter = paramTree.value(forKey: "h_gain") as? AUParameter
        vgainParameter = paramTree.value(forKey: "v_gain") as? AUParameter
        print(hgainParameter!.value)
        presetController!.audioUnit = audioUnit
        presetController!.restoreState()
        
        //presetController!.loadPresets()
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
        
        //let theNoteBlock = audioUnit!.scheduleMIDIEventBlock
        noteBlock = audioUnit!.scheduleMIDIEventBlock
        
        audioUnit?.setLoopMode(0)
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
            videoButton.tintColor = UIColor.red
            setButtonIcon(videoButton, named: "circle.fill")
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
            setButtonIcon(videoButton, named: "stop.fill")
        case .idle:
            setButtonIcon(videoButton, named: "circle.fill")
        }
        
        if (interfaceDelegate?.recordingsAvailable() ?? false)
        {
            videoButton.tintColor = UIColor.yellow
            setButtonIcon(videoButton, named: "folder")
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
    
    @IBAction func loopStart(_ sender: Any) {
        switch audioUnit?.getLoopMode() {
        case 0: // stopped
            audioUnit?.setLoopMode(1)
        case 1: // rec
            audioUnit?.setLoopMode(2)
        case 2: // play
            audioUnit?.setLoopMode(3)
        case 3: // play/rec
            audioUnit?.setLoopMode(2)
        case 4: // pause
            audioUnit?.setLoopMode(2)
        default:
            break
        }
        syncLoopButtons()
    }
    
    @IBAction func loopStop(_ sender: Any) {
        switch audioUnit?.getLoopMode() {
        case 0:
            break
        case 1,2,3:
            audioUnit?.setLoopMode(4)
        case 4:
            audioUnit?.setLoopMode(0)
        default:
            break
        }
        syncLoopButtons()
    }
    
    func syncLoopButtons()
    {
        var playImage = "circle.fill"
        var stopImage = "pause.fill"
        switch audioUnit?.getLoopMode() {
        case 0:
            stopImage = "stop.fill"
            break
        case 1:
            playImage = "play.fill"
            break
        case 2:
            break
        case 3:
            playImage = "play.fill"
        case 4:
            stopImage = "stop.fill"
            playImage = "play.fill"
            break
        default:
            break
        }
        
        setButtonIcon(loopRecButton, named: playImage)
        setButtonIcon(loopStopButton, named: stopImage)
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
