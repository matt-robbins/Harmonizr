/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for the FilterDemo audio unit. Manages the interactions between a FilterView and the audio unit's parameters.
*/

import UIKit
import CoreAudioKit

public class FilterDemoViewController: AUViewController, FilterViewDelegate {
    // MARK: Properties

    @IBOutlet weak var filterView: FilterView!
	@IBOutlet weak var frequencyLabel: UILabel!
	@IBOutlet weak var resonanceLabel: UILabel!
    
    /*
		When this view controller is instantiated within the FilterDemoApp, its 
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
                    self.restoreState()
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
	var parameterObserverToken: AUParameterObserverToken?
    
    var configController: ConfigViewController?
    
    var timer = Timer()
    
    func auPoller(T: Float){
        // Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(updateCounting), userInfo: nil, repeats: true)
    }
    
    func updateCounting()
    {
        guard let audioUnit = audioUnit else { return }
        filterView.setSelectedNote(audioUnit.getCurrentNote())
        // update visible keycenter based on computed value from midi
        filterView.setSelectedKeycenter(audioUnit.getCurrentKeycenter())
        return
    }

	public override func viewDidLoad() {
		super.viewDidLoad()
		
		// Respond to changes in the filterView (frequency and/or response changes).
        filterView.delegate = self
        
        auPoller(T: 0.1)
		configController = self.storyboard?.instantiateViewController(withIdentifier: "configView") as? ConfigViewController
        let _: UIView = configController!.view
        
        guard audioUnit != nil else { return }
        self.restoreState()
        connectViewWithAU()
        
	}
    
    // MARK: FilterViewDelegate
    
    func updateFilterViewFrequencyAndMagnitudes() {
        //guard let audioUnit = audioUnit as AUv3FilterDemo! else { return }
        //filterView!.setSelectedKeycenter(keycenterParameter!.value)
        return
    }
    
    func filterView(_ filterView: FilterView, didChangeKeycenter keycenter: Float)
    {
        keycenterParameter?.value = keycenter
    }
    
    func filterView(_ filterView: FilterView, didChangeInversion inversion: Float)
    {
        inversionParameter?.value = inversion
    }
    
    func filterView(_ filterView: FilterView, didChangeNvoices voices: Float)
    {
        nvoicesParameter?.value = voices
    }
    
    func filterView(_ filterView: FilterView, didChangeAuto enable: Float)
    {
        autoParameter?.value = enable
    }
    
    func filterView(_ filterView: FilterView, didChangeTriad triad: Float)
    {
        triadParameter?.value = triad
    }
    
    func filterView(_ filterView: FilterView, didChangeMidi midi: Float)
    {
        midiParameter?.value = midi
    }
    
    func filterView(_ filterView: FilterView, didChangeBypass bypass: Float)
    {
        print(bypass)
        bypassParameter?.value = bypass
    }
    
    func filterViewDataDidChange(_ filterView: FilterView) {
        updateFilterViewFrequencyAndMagnitudes()
    }
    
    func filterViewGetPitch(_ filterView: FilterView) -> Float {
        return audioUnit!.getCurrentNote()
    }
    func filterViewGetKeycenter(_ filterView: FilterView) -> Float {
        return keycenterParameter!.value
    }
    
    func filterViewGetPreset(_ filterView: FilterView) -> String {
        return audioUnit!.currentPreset!.name
    }
    
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
        let f = stateURL()
        let s = NSKeyedUnarchiver.unarchiveObject(withFile: f.path) as? [String: Any]
        if (s != nil)
        {
            self.audioUnit!.fullState = s
        }
    }
    
    func filterView(_ filterView: FilterView, didChangePreset preset: Int) {
        print("setting preset index to \(preset)")
        if (preset < self.audioUnit!.factoryPresets!.count) {
            self.audioUnit!.currentPreset = self.audioUnit!.factoryPresets?[preset]
            filterView.preset = self.audioUnit!.currentPreset
            saveState()
        }
    }
    
    func filterViewSavePreset(_ filterVew: FilterView)
    {
        saveState()
    }
    
    func filterViewConfigure(_ filterView: FilterView) {
        
//        for j in 0...36 {
//            let param = paramTree.value(forKey: "interval_\(j)") as? AUParameter
//            param!.value = 0.0
//        }
        DispatchQueue.main.async {
            self.configController!.audioUnit = self.audioUnit
            self.configController!.refresh()
            self.present(self.configController!, animated:true, completion:nil)
            
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
        
        
        let sem = DispatchSemaphore(value: 0)
        
        // set up a background queue for param change notifications
        DispatchQueue.global(qos: .background).async {
            var count: Int = -1
            while (true)
            {
                if (sem.wait(timeout: DispatchTime(uptimeNanoseconds: 1000000)) == DispatchTimeoutResult.success)
                {
                    count = 1
                }
                else if (count > -1)
                {
                    if (count == 0)
                    {
                        self.saveState()
                    }
                    count -= 1
                }
            }
        }
		
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let strongSelf = self else { return }
            
            print(address)
            if (true)
            {
                DispatchQueue.main.async {
                    sem.signal()
                    //strongSelf.saveState()
                }
            }
		})
        
        configController!.refresh()
        
        filterView.presets = (audioUnit?.factoryPresets)!
        filterView.preset = audioUnit!.currentPreset
        
        filterView.setSelectedVoices(Int(nvoicesParameter!.value), inversion: Int(inversionParameter!.value))
        filterView.setSelectedKeycenter(keycenterParameter!.value)
        filterView.inversion = Int(inversionParameter!.value)
        filterView.bypass = Int(bypassParameter!.value)
        filterView.auto_enable = Int(autoParameter!.value)
        filterView.midi_enable = Int(midiParameter!.value)
	}
}
