/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller which registers an AUAudioUnit subclass in-process for easy development, connects sliders and text fields to its parameters, and embeds the audio unit's view into a subview. Uses SimplePlayEngine to audition the effect.
*/

import UIKit
import ReplayKit
import CoreAudioKit
import AudioToolbox
import AVFoundation
import HarmonizerFramework

extension UINavigationController {
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return visibleViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
    }

    open override var shouldAutorotate: Bool {
        return visibleViewController?.shouldAutorotate ?? super.shouldAutorotate
    }
}

class ViewController: UIViewController, InterfaceDelegate {
    // MARK: Properties

    @IBOutlet weak var navBar: UINavigationItem!
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var reverbButton: UIButton!
    @IBOutlet var playButton: UIButton!
    @IBOutlet weak var bgSwitch: UISwitch!
    @IBOutlet weak var recordButton: UIBarButtonItem!
    @IBOutlet weak var folderButton: UIBarButtonItem!
    @IBOutlet weak var screenRecordButton: UIBarButtonItem!
    @IBOutlet weak var auTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var auAspectConstraint: NSLayoutConstraint!
    
    @IBOutlet var baseView: BaseView!
    /// Container for our custom view.
    @IBOutlet var auContainerView: UIView!

	/// The audio playback engine.
    var audioEngine: AudioEngine2!
    var harmUnit: AUAudioUnit!
    
    var recordWindow: UIWindow?

	/// A token for our registration to observe parameter value changes.
	var parameterObserverToken: AUParameterObserverToken!

	/// Our plug-in's custom view controller. We embed its view into `viewContainer`.
	//var filterDemoViewController: FilterDemoViewController!
    var harmonizerViewController: HarmonizrMainViewController!

    var btMidiViewController: CABTMIDICentralViewController!
    var navController: UINavigationController!
    
    var reverbMix: Float = 0
    var reverbEnabled = true
    
    var reverbMixParam: AUParameter?
    
    var previewView: UIView? = nil
    var recTimeView: UIView? = nil
    
    var recordingMode:Bool = false
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        
        return recordingMode ? .portrait : .landscapeRight
    }

    // MARK: View Life Cycle
    
    override func viewDidAppear(_ animated: Bool)
    {
        //audioEngine.start()
        if audioEngine.bluetoothAudioConnected()
        {
            let explain = "There will be significant delay. For the best experience, please connect wired headphones or an external audio device."
            
            let alert = UIAlertController(title: "Bluetooth Connected", message: explain, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Gotcha", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    override func preferredScreenEdgesDeferringSystemGestures() -> UIRectEdge {
        return [.bottom,.top,.left,.right]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
        
        //self.view.backgroundColor = UIColor.darkGray
		// Set up the plug-in's custom view.
		embedPlugInView()
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
		self.setNeedsStatusBarAppearanceUpdate()
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
        AUAudioUnit.registerSubclass(AUv3Harmonizer.self, as: componentDescription, name:"MrFx: Harmonizer", version: 6)
        
        // diable idle timer
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.audioEngine = AudioEngine2()
        
        self.audioEngine.loadComponent(componentDescription: componentDescription, completionHandler: {(audioUnit) in
            self.harmUnit = audioUnit
            //self.getAUView()
            
            self.harmonizerViewController.audioUnit = self.harmUnit as? AUv3Harmonizer
            
            self.audioEngine.start()            
        })
        
        
        //print(Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String)
        
        reverbMixParam = audioEngine.reverbUnit!.parameterTree!.parameter(withAddress: AUParameterAddress(kReverb2Param_DryWetMix))
        reverbMixParam?.value = 5
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
        
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        let tut = defaults?.bool(forKey: "wantsTutorial")
        if (tut == true)
        {
            defaults?.set(false,forKey: "wantsTutorial")
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "tutorialOverlay")
            //self.addChildViewController(vc!)
            
            let window = UIApplication.shared.keyWindow
            window!.addSubview(vc!.view)
            //vc!.didMove(toParentViewController: self)
        }
        
//        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped))
//        edgePan.edges = .left
//
//        view.addGestureRecognizer(edgePan)
	}
    
    @objc private func appMovedToBackground()
    {
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        let bgmode = defaults?.bool(forKey: "bgModeEnable") ?? false
        if (!bgmode)
        {
            self.audioEngine.stop()
        }
    }
    
    @objc private func appMovedToForeground()
    {
        self.audioEngine.start()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "mainToReverb") {
            let vc = segue.destination as! ReverbViewController
            vc.audioUnit = audioEngine.reverbUnit
        }
        if (segue.identifier == "mainToFiles")
        {
            folderButton.tintColor = self.view.tintColor
            let vc = segue.destination as! FilesTableViewController
            //vc.audioEngine = audioEngine
        }
        if (segue.identifier == "mainMenu")
        {
            let vc = segue.destination as! MainMenuTableViewController
            vc.audioEngine = audioEngine
        }
    }
    
	/// Called from `viewDidLoad(_:)` to embed the plug-in's view into the app's view.
	func embedPlugInView() {
        /*
			Locate the app extension's bundle, in the app bundle's PlugIns
			subdirectory. Load its MainInterface storyboard, and obtain the
            viewController from that.
        */
        let builtInPlugInsURL = Bundle.main.builtInPlugInsURL!
        let pluginURL = builtInPlugInsURL.appendingPathComponent("HarmonizerExtension.appex")
		let appExtensionBundle = Bundle(url: pluginURL)

        let storyboard = UIStoryboard(name: "MainInterface", bundle: appExtensionBundle)
        
        harmonizerViewController = storyboard.instantiateInitialViewController() as? HarmonizrMainViewController
//
        // Present the view controller's view.
        constrainPluginView()
	}
	
    func constrainPluginView()
    {
        if let view = harmonizerViewController.view {
            addChildViewController(harmonizerViewController)
            //view.frame = auContainerView.bounds
            auContainerView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.topAnchor.constraint(equalTo: auContainerView.topAnchor, constant: 0).isActive = true
            view.bottomAnchor.constraint(equalTo: auContainerView.bottomAnchor, constant: 0).isActive = true
            view.leadingAnchor.constraint(equalTo: auContainerView.leadingAnchor, constant: 0).isActive = true
            view.trailingAnchor.constraint(equalTo: auContainerView.trailingAnchor, constant: 0).isActive = true
            auContainerView.autoresizesSubviews = true
            
            harmonizerViewController.didMove(toParentViewController: self)
            harmonizerViewController!.interfaceDelegate = self
        }
    }
    
    func getAUView()
    {
        harmUnit!.requestViewController { [weak self] viewController in
            guard let strongSelf = self else { return }
                    // Only update the view if the view controller has one.
            guard let viewController = viewController else {

                fatalError("no view!!!")
            }
            
            if let view = viewController.view {
                strongSelf.harmonizerViewController = viewController as? HarmonizrMainViewController
                strongSelf.addChildViewController(viewController)
                view.frame = strongSelf.auContainerView.bounds
                
                strongSelf.auContainerView.addSubview(view)
                viewController.didMove(toParentViewController: self)
            }
        }
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
        navController.dismiss(animated: false, completion: nil)
        navController = nil
        btMidiViewController = nil
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if UIDevice.current.orientation.isPortrait {
            print("Portrait")
        } else {
            print("Landscape")
        }
    }
    
    // MARK: IBActions

    @IBAction func screenRecordToggle(_ sender: UIBarButtonItem) {
        let screenRecorder = RPScreenRecorder.shared()

        if (!screenRecorder.isRecording)
        {
            recordingMode = true
            
            
            //UIViewController.attemptRotationToDeviceOrientation()

            let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
            
            screenRecorder.isCameraEnabled = (defaults?.bool(forKey: "cameraEnable") ?? false)
            print("camera enabled: \(screenRecorder.isCameraEnabled)")
            if (screenRecorder.isCameraEnabled)
            {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
            
            screenRecorder.startRecording(handler: {
                (error) in
                guard error == nil else {
                    print("count't start recording: \(error?.localizedDescription ?? "??")")
                    return
                }
                
                self.previewView = screenRecorder.cameraPreviewView
                if let preview = self.previewView {
                    
                    
                    if let vview = self.harmonizerViewController.getVideoView()
                    {
                        preview.translatesAutoresizingMaskIntoConstraints = false
                        //preview.isUserInteractionEnabled = false
                        preview.frame = vview.bounds
                        vview.addSubview(preview)
                    }
                    
                    
                    let tap = UITapGestureRecognizer(target: self, action: #selector(self.videoStop))
                    preview.addGestureRecognizer(tap)
                    
                    self.view.bringSubview(toFront: self.auContainerView)
                }
            })
        }
        else
        {
            screenRecorder.stopRecording(handler: {
                (previewController, error) in

                guard error == nil else {
                    print("couldn't stop recording: \(error?.localizedDescription ?? "??")")
                    return
                }
                                
                previewController?.previewControllerDelegate = self
                self.present(previewController!, animated: true)
                let presentationController = previewController?.popoverPresentationController
                presentationController?.barButtonItem = self.screenRecordButton
                
                
                
                self.recordingMode = false
                
                self.setNeedsStatusBarAppearanceUpdate()
                
            })
        }
    }
    
    
    @IBAction func recordToggle(_ sender: Any) {
        if (audioEngine.isRecording())
        {
            audioEngine.finishRecording()
            if #available(iOS 13.0, *) {
                recordButton.image = UIImage(systemName: "circle.fill")
                folderButton.tintColor = .yellow
            } else {
                recordButton.title = "recording..."
            }
        }
        else
        {
            if #available(iOS 13.0, *) {
                recordButton.image = UIImage(systemName: "pause.circle.fill")
            } else {
                recordButton.title = "record"
            }
            audioEngine.startRecording()
        }
    }
    
    @IBAction func toggleBackgroundMode(_ sender: UISwitch)
    {
        
    }
    
    func didToggleRecording(_ onOff:Bool) -> Bool
    {
        //
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        let video = defaults?.bool(forKey: "recordVideo") ?? false
        
        if (!video)
        {
            if (audioEngine.isRecording())
            {
                audioEngine.finishRecording()
                recTimeView?.removeFromSuperview()
                recTimeView = nil
                return false
            }
            else
            {
                audioEngine.startRecording()
                recTimeView = UIView()
                recTimeView?.backgroundColor = UIColor.black
                recTimeView?.layer.opacity = 0.5
                recTimeView?.layer.cornerRadius = 4
                
                recTimeView?.isUserInteractionEnabled = false
                
                self.view.addSubview(recTimeView!)
                recTimeView?.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
                recTimeView?.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
                
                let centerX = (self.view.bounds.maxX - self.view.bounds.minX)/2
                let centerY = (self.view.bounds.maxY - self.view.bounds.minY)/2
                recTimeView?.frame = CGRect(x: CGFloat(centerX - centerX/2), y: CGFloat(centerY*3/4), width: centerX, height: centerY/4)
                return true
            }
        }
        
        screenRecordToggle(screenRecordButton)
        let screenRecorder = RPScreenRecorder.shared()
        return !screenRecorder.isRecording
    }
    func getReverbUnit() -> AUAudioUnit?
    {
        return audioEngine.reverbUnit
    }
    
    func getInputViewController() -> UIViewController?
    {
        return self.storyboard?.instantiateViewController(withIdentifier: "inputController")
    }
    
    func showNavBar(_ show: Bool) {
        self.navigationController?.setNavigationBarHidden(show, animated: true)
    }
    
    @objc func videoStop()
    {
        screenRecordToggle(screenRecordButton)
    }
    
    @objc func screenEdgeSwiped()
    {
        print("edge swipe!")
        if (self.navigationController?.isNavigationBarHidden ?? false)
        {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
        }
        else
        {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }
    
}

extension ViewController: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
        RPScreenRecorder.shared().discardRecording {
            print("discarding!")
        }
        self.previewView?.removeFromSuperview()
        self.previewView = nil
        
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
    }
}
