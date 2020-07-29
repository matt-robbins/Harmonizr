//
//  TutorialViewController.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 7/23/20.
//

import Foundation
import UIKit
import AudioToolbox
import AVFoundation


class TutorialView: UIView {
    
    var button:UIButton?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let p = button?.convert(point, from: self)
        {
            return button?.point(inside: p, with: event) ?? false
        }
        
        return false
    }
}

class TutorialViewController: UIViewController {

    @IBOutlet var background: TutorialView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var auxLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    @IBOutlet weak var vuMeter: VUMeter!
    private var parameterTree: AUParameterTree? = nil
    private var parameterObserverToken: AUParameterObserverToken!
    
    private var keycenterParameter: AUParameter?
    private var nvoicesParameter: AUParameter?
    
    var harmViewController: HarmonizerViewController?
    
    private var keycenterCount = 0
    private var triedKeycenter = false {
        didSet {
            keycenterCount += 1
            if (state == 2 && level_count > 20 && keycenterCount > 5)
            {
                state = 3
                keycenterCount = 0
                voicesCount = 0
            }
            
            if (state == 1 && keycenterCount > 3)
            {
                state = 2
                keycenterCount = 0
            }
            
        }
    }
    private var voicesCount = 0
    private var triedVoices = false
    {
        didSet {
            voicesCount += 1
            if (state == 3 && voicesCount > 3 && level_count > 20)
            {
                keyboardCount = 0
                state = 4
            }
        }
    }
    private var keyboardCount = 0
    private var triedKeyboard = false
    {
        didSet {
            if (oldValue == true && triedKeyboard == false)
            {
                keyboardCount += 1
                
                if (state == 4 && keyboardCount > 5 && level_count > 20)
                {
                    state = 5
                }
            }
        }
    }
    
    private var keyOffset = 0
    {
        didSet {
            if (state == 5 && keyOffset != oldValue)
            {
                state = 6
            }
        }
    }
    
    private var level = 0.0
    private var level_count = 0
    private var note_count = 0
    
    var callback : ((Int?) -> Void)?
    
    var state = 0 {
        didSet {
            level_count = 0
            
            progressBar.progress = Float(state) / 5.0
            switch (state)
            {
            case 0:
                harmViewController?.tutorial_highlight(.none)
                break
            case 1:
                
                //self.progressBar.isHidden = true
                self.instructionLabel.text = "good! Now, try switching keycenters by tapping and/or dragging!"
                //self.view.isUserInteractionEnabled = false
                
                UIView.animate(withDuration: 0.5, animations: {
                    self.background.backgroundColor = UIColor.init(white: 1, alpha: 0.1)
                })
                
                harmViewController?.tutorial_highlight(.keycenter)
                //self.updater?.isPaused = true
                
                break
            case 2:
                UIView.transition(with: self.instructionLabel,
                     duration: 0.25,
                      options: .transitionCrossDissolve,
                   animations: { [weak self] in
                       self?.instructionLabel.text = "Try singing at the same time and listen to how the harmony changes. Try singing through a scale that feels right. Try it out with a few major, minor, and dominant key centers."
                }, completion: nil)

                break
            case 3:
                UIView.animate(withDuration: 0.5, animations: {
                    self.background.backgroundColor = UIColor.init(white: 0.1, alpha: 0.0)
                })
                auxLabel.text = "great! Switch the number of Voices and their inversions!"
                auxLabel.isHidden = false
                instructionLabel.text = ""
                harmViewController?.tutorial_highlight(.voices)
                //self.view.isUserInteractionEnabled = true
                break
            case 4:
                auxLabel.isHidden = true
                instructionLabel.text = "try playing some notes on the built-in keyboard, or with an external midi controller. You can change the range of the keyboard by tapping on the left and right arrows to the right, or by dragging above the top boundary and then sliding sideways."
                harmViewController?.tutorial_highlight(.keyboard)
                
                break
                
            case 5:
                instructionLabel.text = "You can change the range of the keyboard by tapping on the left and right arrows to the right, or by dragging above the top boundary and then sliding sideways."
                harmViewController?.keyboardView!.raise()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.harmViewController?.keyboardView!.lower()
                }
                break

            default:
                let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
                defaults?.set(true, forKey: "doneTutorial")
                harmViewController?.tutorial_highlight(.none)
                self.updater = nil
                nvoicesParameter?.removeParameterObserver(parameterObserverToken)
                keycenterParameter?.removeParameterObserver(parameterObserverToken)
                if let cb = callback {
                    cb(0)
                }
                break
            }
        }
    }
    
    var updater:CADisplayLink? = nil
    
    public var audioUnit: AUv3Harmonizer? = nil
    {
        didSet {
            parameterTree = audioUnit?.parameterTree
            
            keycenterParameter = parameterTree?.value(forKey: "keycenter") as? AUParameter
            nvoicesParameter = parameterTree?.value(forKey: "nvoices") as? AUParameter
            
            parameterObserverToken = parameterTree?.token(byAddingParameterObserver: { [weak self] address, _ in
                guard let self = self else { return }
                /*
                 This is called when one of the parameter values changes.
                 We can only update UI from the main queue.
                 */
                DispatchQueue.main.async {
                    if address == self.keycenterParameter?.address {
                        self.triedKeycenter = true
                    } else if address == self.nvoicesParameter?.address {
                        self.triedVoices = true
                    }
                }
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updater = CADisplayLink(target: self, selector: #selector(updateDisplay))
        updater?.add(to: .current, forMode: .defaultRunLoopMode)
        updater?.isPaused = false
        
        auxLabel.isHidden = true
        
        if let v = self.view as? TutorialView
        {
            v.button = cancelButton
        }
        
        self.view.isUserInteractionEnabled = true
        
        cancelButton.backgroundColor = UIColor.init(white: 0.0, alpha: 0.5)
        cancelButton.layer.cornerRadius = 5
        
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    
    @objc private func updateDisplay()
    {
        guard let audioUnit = audioUnit else { return }
        
        level = Double(audioUnit.getCurrentLevel())
        vuMeter.set_gain(gain: Float(level))
        let note = Float(audioUnit.getCurrentNote())
        let keys = audioUnit.getKeysDown()!
        
        keyOffset = harmViewController?.keyboardView.keyOffset ?? 0
        var tkb = false
        for k in 0 ..< keys.count
        {
            if (keys[k] as! Bool)
            {
                tkb = true
            }
        }
        triedKeyboard = tkb
        
        if (note > 0)
        {
            level_count+=1
            if (level_count >= 20 && state == 0)
            {
                state = 1
            }
        }
        else
        {
            level_count = 0
        }
        
        //progressBar.setProgress(Float(level_count)/20.0, animated: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func cancel(_ sender: UIButton) {
        
        state += 1
    }
}
