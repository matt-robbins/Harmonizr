/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the FilterDemo audio unit. Manages the interactions between a FilterView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit
import os

public class HarmonizerViewController: AUViewController, HarmonizerViewDelegate, VoicesViewDelegate, KeyboardViewDelegate {
    // MARK: Properties

    @IBOutlet weak var harmonizerView: HarmonizerView!
    @IBOutlet weak var voicesView: HarmonizerVoicesView!
    
    @IBOutlet weak var keyboardView: KeyboardView!
    
    @IBOutlet weak var midiButton: HarmButton!
    @IBOutlet weak var autoButton: HarmButton!
    
    @IBOutlet weak var presetPrevButton: HarmButton!
    @IBOutlet weak var presetNextButton: HarmButton!
    @IBOutlet weak var presetEditButton: HarmButton!
    @IBOutlet weak var presetLabel: UILabel!
    
    @IBOutlet var presetFavorites: [HarmButton]!
    
    private var noteBlock: AUScheduleMIDIEventBlock!
    
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
    var presetController: PresetController?
    
    var presetModified: Bool = false {
        didSet {

        }
    }

    var timer = Timer()
    
    func auPoller(T: Float){
        // Scheduling timer to Call the timerFunction
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
    }
    
    @objc func timerFunction()
    {
        guard let audioUnit = audioUnit else { return }
        harmonizerView.setSelectedNote(audioUnit.getCurrentNote())
        keyboardView.setCurrentNote(audioUnit.getMidiNote())
        // update visible keycenter based on computed value from midi
        harmonizerView.setSelectedKeycenter(audioUnit.getCurrentKeycenter())
        return
    }

	public override func viewDidLoad() {
		super.viewDidLoad()
		
		// Respond to changes in the filterView (frequency and/or response changes).
        harmonizerView.delegate = self
        voicesView.delegate = self
        keyboardView.delegate = self
        
        presetController = PresetController()
        
        auPoller(T: 0.1)
		configController = self.storyboard?.instantiateViewController(withIdentifier: "configView") as? ConfigViewController
        let _: UIView = configController!.view
        
        connectViewWithAU()
	}
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //syncView()
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
    
    //MARK: KeyboardViewDelegate
    
    func keyboardView(_ view: KeyboardView, noteOn note: Int) {
        let cbytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
        cbytes[0] = 0x90
        cbytes[1] = UInt8(note)
        cbytes[2] = 64
        self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
    }
    
    func keyboardView(_ view: KeyboardView, noteOff note: Int) {
        let cbytes = UnsafeMutablePointer<UInt8>.allocate(capacity: 3)
        cbytes[0] = 0x80
        cbytes[1] = UInt8(note)
        cbytes[2] = 64
        self.noteBlock(AUEventSampleTimeImmediate, 0, 3, cbytes)
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
        
        presetController!.audioUnit = audioUnit
        presetController!.restoreState()
        
        var pendingRequestWorkItem: DispatchWorkItem?
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            pendingRequestWorkItem?.cancel()
            let requestWorkItem = DispatchWorkItem { [weak self] in self?.presetController?.saveState() }
            pendingRequestWorkItem = requestWorkItem
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250),
                                          execute: requestWorkItem)
		})
        
        configController!.refresh()
        
        let theNoteBlock = audioUnit!.scheduleMIDIEventBlock
        
        noteBlock = theNoteBlock
        
        syncView()
	}
    
    private func syncView()
    {
        if (audioUnit != nil)
        {
            midiButton.isSelected = (midiParameter!.value == 1)
            autoButton.isSelected = (autoParameter!.value == 1)
            
            voicesView.setSelectedVoices(Int(nvoicesParameter!.value), inversion: Int(inversionParameter!.value))
            
            harmonizerView.setSelectedKeycenter(keycenterParameter!.value)
        }
        
        if ((presetController) != nil)
        {
            presetPrevButton.isEnabled = (presetController!.canDecrement())
            presetNextButton.isEnabled = (presetController!.canIncrement())
            
            presetLabel.text = presetController!.currentPreset().name
            
            for k in 0...5
            {
                presetFavorites[k].isSelected = presetController!.presetIx == presetController!.favorites[k]
            }
        }
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
        presetController?.incrementPreset(inc: -1)
        syncView()
    }
    
    @IBAction func presetNext(_ sender: Any) {
        presetController?.incrementPreset(inc: 1)
        syncView()
    }
    
    
    @IBAction func setPreset(_ sender: HarmButton) {
        for b in presetFavorites {
            if (b === sender)
            {
                self.presetController?.loadPresets()
                var ix = self.presetController?.favorites[b.keycenter]

                if (ix == nil) {
                    ix = b.keycenter
                }
                self.presetController?.selectPreset(preset: ix!)
                syncView()
            }
        }
    }
    
    @IBAction func presetConf(_ sender: HarmButton) {
        self.configController!.audioUnit = self.audioUnit
        self.configController!.presetController = self.presetController
        self.configController!.doneFcn = {
            self.syncView()
        }
        
        sender.isSelected = true
        
        //performSegue(withIdentifier: "configurePreset", sender: self)
        //
        self.present(self.configController!, animated:true, completion:
            {
                self.presetModified=true
                self.configController!.refresh()
                sender.isSelected = false
                self.syncView()
        })
    }
    
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        guard let button = sender.view as! HarmButton?
        else
        {
            return
        }
        
        performSegue(withIdentifier: "fastPreset", sender:button)
    }
    
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {

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
    }
    
}
