/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller which registers an AUAudioUnit subclass in-process for easy development, connects sliders and text fields to its parameters, and embeds the audio unit's view into a subview. Uses SimplePlayEngine to audition the effect.
*/

import UIKit
import CoreAudioKit
import AudioToolbox
import FilterDemoFramework

class ViewController: UIViewController {
    // MARK: Properties

    @IBOutlet weak var presetButton: UIButton!
    @IBOutlet var playButton: UIButton!

//    @IBOutlet var cutoffSlider: UISlider!
//    @IBOutlet var resonanceSlider: UISlider!
//
//    @IBOutlet var cutoffTextField: UITextField!
//    @IBOutlet var resonanceTextField: UITextField!

    /// Container for our custom view.
    @IBOutlet var auContainerView: UIView!

	/// The audio playback engine.
	var playEngine: SimplePlayEngine!

	/// A token for our registration to observe parameter value changes.
	var parameterObserverToken: AUParameterObserverToken!

	/// Our plug-in's custom view controller. We embed its view into `viewContainer`.
	var filterDemoViewController: FilterDemoViewController!
    
    var btMidiViewController: CABTMIDICentralViewController!
    var navController: UINavigationController!

    // MARK: View Life Cycle
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
        self.view.backgroundColor = UIColor.darkGray
		// Set up the plug-in's custom view.
		embedPlugInView()
		
		// Create an audio file playback engine.
		playEngine = SimplePlayEngine(componentType: kAudioUnitType_MusicEffect)
        {
            for u in self.playEngine.availableAudioUnits
            {
                print(u.name)
                print("0x\(String(u.audioComponentDescription.componentType,radix: 16))")
                print("0x\(String(u.audioComponentDescription.componentSubType,radix: 16))")
                print("0x\(String(u.audioComponentDescription.componentManufacturer,radix: 16))")
            }
        }
		
		/*
			Register the AU in-process for development/debugging.
			First, build an AudioComponentDescription matching the one in our 
            .appex's Info.plist.
		*/
        // MARK: AudioComponentDescription Important!
        // Ensure that you update the AudioComponentDescription for your AudioUnit type, manufacturer and creator type.
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_MusicEffect
        componentDescription.componentSubType = 0x6861726d /*'harm'*/
        componentDescription.componentManufacturer = 0x44656d6f /*'Demo'*/
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
		
		/*
			Register our `AUAudioUnit` subclass, `AUv3FilterDemo`, to make it able 
            to be instantiated via its component description.
			
			Note that this registration is local to this process.
		*/
        AUAudioUnit.registerSubclass(AUv3FilterDemo.self, as: componentDescription, name:"Demo: Local FilterDemo", version: UInt32.max)
        
		// Instantiate and insert our audio unit effect into the chain.
		playEngine.selectAudioUnitWithComponentDescription(componentDescription) {
			// This is an asynchronous callback when complete. Finish audio unit setup.
			self.connectParametersToControls()
		}
        
        presetButton.setTitle("Reverb", for: UIControlState())
        presetButton.setTitleColor(UIColor.white, for: UIControlState())
        playButton.setTitle("Bluetooth", for: UIControlState())
        playButton.setTitleColor(UIColor.white, for: UIControlState())
        //playButton.setImage(UIImage(named: "bt_icon.svg")!, for: UIControlState())
        // diable idle timer
        UIApplication.shared.isIdleTimerDisabled = true
        playEngine.startPlaying()
        
	}
    

	
	/// Called from `viewDidLoad(_:)` to embed the plug-in's view into the app's view.
	func embedPlugInView() {
        /*
			Locate the app extension's bundle, in the app bundle's PlugIns
			subdirectory. Load its MainInterface storyboard, and obtain the
            `FilterDemoViewController` from that.
        */
        let builtInPlugInsURL = Bundle.main.builtInPlugInsURL!
        let pluginURL = builtInPlugInsURL.appendingPathComponent("FilterDemoAppExtension.appex")
		let appExtensionBundle = Bundle(url: pluginURL)

        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)
		filterDemoViewController = storyboard.instantiateInitialViewController() as! FilterDemoViewController
        
        // Present the view controller's view.
        if let view = filterDemoViewController.view {
            addChildViewController(filterDemoViewController)
            view.frame = auContainerView.bounds
            
            auContainerView.addSubview(view)
            filterDemoViewController.didMove(toParentViewController: self)
        }
	}
	
	/**
        Called after instantiating our audio unit, to find the AU's parameters and
        connect them to our controls.
    */
	func connectParametersToControls() {
		// Find our parameters by their identifiers.
        guard let parameterTree = playEngine.testAudioUnit?.parameterTree else { return }

        let audioUnit = playEngine.testAudioUnit as! AUv3FilterDemo
        
        let presets = audioUnit.factoryPresets
        filterDemoViewController.audioUnit = audioUnit
        audioUnit.currentPreset = presets?[0]
	}
    
    func dismissPopover() {
        navController.dismiss(animated: true, completion: nil)
        navController = nil
        btMidiViewController = nil
    }

    // MARK: IBActions

	/// Handles Play/Stop button touches.
    @IBAction func togglePlay(_ sender: AnyObject?) {
		//let isPlaying = playEngine.togglePlay()
        
        btMidiViewController = CABTMIDICentralViewController()
        navController = UINavigationController(rootViewController: btMidiViewController)
        
        btMidiViewController.navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(ViewController.dismissPopover))
        navController.modalPresentationStyle = UIModalPresentationStyle.popover
        
        self.present(navController, animated: true, completion: nil)
	}
	
    @IBAction func configureReverb(_ sender: UITapGestureRecognizer) {
        playEngine.reverbAudioUnit!.parameterTree!.parameter(withAddress: AUParameterAddress(kReverb2Param_DryWetMix))!.value = 50.0
    }
    @IBAction func toggleReverb(_ sender: UILongPressGestureRecognizer) {
        print("helloooooo!")
    }

}
