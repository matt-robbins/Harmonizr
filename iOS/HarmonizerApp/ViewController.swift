/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller which registers an AUAudioUnit subclass in-process for easy development, connects sliders and text fields to its parameters, and embeds the audio unit's view into a subview. Uses SimplePlayEngine to audition the effect.
*/

import UIKit
import CoreAudioKit
import AudioToolbox
import AVFoundation
import HarmonizerFramework

class ViewController: UIViewController {
    // MARK: Properties

    @IBOutlet weak var reverbButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet weak var bgSwitch: UISwitch!
//    @IBOutlet var cutoffSlider: UISlider!
//    @IBOutlet var resonanceSlider: UISlider!
//
//    @IBOutlet var cutoffTextField: UITextField!
//    @IBOutlet var resonanceTextField: UITextField!

    /// Container for our custom view.
    @IBOutlet var auContainerView: UIView!

	/// The audio playback engine.
	//var playEngine: SimplePlayEngine!
    var audioEngine: AudioEngine2!
    var harmUnit: AUAudioUnit!

	/// A token for our registration to observe parameter value changes.
	var parameterObserverToken: AUParameterObserverToken!

	/// Our plug-in's custom view controller. We embed its view into `viewContainer`.
	//var filterDemoViewController: FilterDemoViewController!
    var harmonizerViewController: HarmonizerViewController!

    var btMidiViewController: CABTMIDICentralViewController!
    var navController: UINavigationController!
    
    var reverbMix: Float = 0
    var reverbEnabled = true
    
    var reverbMixParam: AUParameter?

    // MARK: View Life Cycle
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
        self.view.backgroundColor = UIColor.darkGray
		// Set up the plug-in's custom view.
		//embedPlugInView()
		
		/*
			Register the AU in-process for development/debugging.
			First, build an AudioComponentDescription matching the one in our 
            .appex's Info.plist.
		*/
        // MARK: AudioComponentDescription Important!
        // Ensure that you update the AudioComponentDescription for your AudioUnit type, manufacturer and creator type.
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_MusicEffect
        componentDescription.componentSubType = 0x4861726d /*'Harm'*/
        componentDescription.componentManufacturer = 0x4d724678 /*'MrFx'*/
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        /*
            Register our `AUAudioUnit` subclass, `AUv3FilterDemo`, to make it able
            to be instantiated via its component description.

            Note that this registration is local to this process.
        */
        AUAudioUnit.registerSubclass(AUv3Harmonizer.self, as: componentDescription, name:"MrFx: Harmonizer", version: 1)
        
        reverbButton.setTitle("Reverb", for: UIControlState())
        reverbButton.setTitleColor(UIColor.white, for: UIControlState())
        playButton.setTitle("Bluetooth", for: UIControlState())
        playButton.setTitleColor(UIColor.white, for: UIControlState())
        //playButton.setImage(UIImage(named: "bt_icon.svg")!, for: UIControlState())
        // diable idle timer
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.audioEngine = AudioEngine2()
        
//        AUAudioUnit.instantiate(with: componentDescription, options: []) { (unit: AUAudioUnit?,error) in
//            self.harmUnit.component = self.audioEngine.effectUnit!
//        }
        
        self.audioEngine.loadComponent(componentDescription: componentDescription, completionHandler: {(audioUnit) in
            self.harmUnit = audioUnit
            self.getAUView()
            
            //self.harmonizerViewController.audioUnit = self.harmUnit as? AUv3Harmonizer
            
            self.audioEngine.start()            
        })
        
        reverbMixParam = audioEngine.reverbUnit!.parameterTree!.parameter(withAddress: AUParameterAddress(kReverb2Param_DryWetMix))
        reverbMixParam?.value = 5
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
	}
    
    @objc private func appMovedToBackground()
    {
        if (!bgSwitch.isOn)
        {
            self.audioEngine.stop()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "mainToReverb") {
            let vc = segue.destination as! ReverbViewController
            vc.audioUnit = audioEngine.reverbUnit
        }
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
		//filterDemoViewController = storyboard.instantiateInitialViewController() as! FilterDemoViewController
        harmonizerViewController = storyboard.instantiateInitialViewController() as! HarmonizerViewController

        // Present the view controller's view.
        if let view = harmonizerViewController.view {
            addChildViewController(harmonizerViewController)
            view.frame = auContainerView.bounds
            
            auContainerView.addSubview(view)
            harmonizerViewController.didMove(toParentViewController: self)
        }
	}
	
    func getAUView()
    {
        harmUnit!.requestViewController { [weak self] viewController in
            guard let strongSelf = self else { return }
        
            // Only update the view if the view controller has one.
            guard let viewController = viewController else {

                print("no view!!!")
                return
            }
            
            if let view = viewController.view {
                strongSelf.harmonizerViewController = viewController as? HarmonizerViewController
                strongSelf.addChildViewController(viewController)
                view.frame = strongSelf.auContainerView.bounds
                
                strongSelf.auContainerView.addSubview(view)
                viewController.didMove(toParentViewController: self)
            }
        }
        
        
        //let presets = harmUnit!.factoryPresets
        //filterDemoViewController.audioUnit = audioUnit
        //harmUnit!.currentPreset = presets?[0]
    }
    
	/**
        Called after instantiating our audio unit, to find the AU's parameters and
        connect them to our controls.
    */
	func connectParametersToControls() {
		// Find our parameters by their identifiers.
        //guard let parameterTree = playEngine.testAudioUnit?.parameterTree else { return }
        
        //let presets = audioUnit.factoryPresets
        //filterDemoViewController.audioUnit = audioUnit
        //audioUnit.currentPreset = presets?[0]
	}
    
    @objc func dismissPopover() {
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
        //navController.modalPresentationStyle = UIModalPresentationStyle.popover
        
        self.present(navController, animated: false, completion: nil)
	}
	
    @IBAction func toggleReverb(_ sender: UITapGestureRecognizer)
    {
        performSegue(withIdentifier: "mainToReverb", sender: self)
        //self.audioEngine.start()
    }
    @IBAction func configureReverb(_ sender: UILongPressGestureRecognizer) {
        performSegue(withIdentifier: "mainToReverb", sender: self)
    }
    
    @IBAction func toggleBackgroundMode(_ sender: UISwitch)
    {
        let explain = "Background mode allows Harmonizr to run while you're using other apps, " +
            "such as MIDI controllers, or if you want to use Harmonizr as an Inter-App Audio effect.  " +
            "Leaving Backround mode on will decrease battery life."
        if (sender === bgSwitch)
        {
            if (sender.isOn)
            {
                let alert = UIAlertController(title: "Background Mode On", message: explain, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                
                self.present(alert, animated: true)
            }
            else
            {
                let alert = UIAlertController(title: "Background Mode Off", message: explain, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                
                self.present(alert, animated: true)
            }
        }
    }
    

}
