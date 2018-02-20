//
//  HarmViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation

import UIKit
import CoreAudioKit

enum tags
{
    
}

class HarmButton: UIButton {
    
    var keycenter: Int = 0
    
    func configure() {
        backgroundColor = .white
        layer.shadowColor = UIColor.cyan.cgColor
        layer.cornerRadius = 4
        layer.borderWidth = 4
        layer.borderColor = UIColor.darkGray.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 8
        layer.masksToBounds = false
        showsTouchWhenHighlighted = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // set other operations after super.init, if required
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // set other operations after super.init if required
        self.configure()
    }
    
    override var isSelected: Bool {
        didSet {
            switch isSelected {
            case true:
                layer.borderColor = UIColor.cyan.cgColor
                layer.shadowOpacity = 1.0
                superview?.bringSubview(toFront: self)
            case false:
                layer.borderColor = UIColor.darkGray.cgColor
                layer.shadowOpacity = 0.0
            }
        }
    }
}

public class HarmView: UIView {
    
    let n_qual: Int = 3
    let n_keys: Int = 12
    let blackkeys = [1,3,6,8,10]
    
    public override func layoutSubviews() {
        let gridwidth: CGFloat = frame.width / 12
        let keywidth = gridwidth * 0.95
        let keyoffset = (gridwidth - keywidth)/2
        let blackoffset = gridwidth / 6.0
        let h = frame.height
        
        //print("layoutSubviews")
        for b in subviews.flatMap({$0 as? HarmButton}) {
            
            let kc = b.keycenter
            let k: Int = kc % n_keys
            let q: Int = kc / n_keys
            
            var offset: CGFloat = 0.0
            if (blackkeys.contains(k))
            {
                offset = blackoffset
            }
            //print("\(k),\(q)")
            b.frame = CGRect(x: gridwidth * CGFloat(k) + keyoffset,
                             y: h - gridwidth * CGFloat(q + 1) + keyoffset - offset,
                             width: keywidth, height: keywidth)
        }
        
        for v in subviews.flatMap({$0 as? KeyglowView}) {
            var offset: CGFloat = 0.0
            let kc = v.keycenter
            
            if (blackkeys.contains(kc))
            {
                offset = blackoffset
            }
            
            let k: Int = kc % n_keys
            v.frame = CGRect(x: gridwidth * CGFloat(k) + keyoffset,
                             y: h - gridwidth*3 + keyoffset - offset,
                             width: keywidth, height: gridwidth*3 - 2 * keyoffset)
        }
    }
}

class KeyglowView: UIView {
    var keycenter:Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // set other operations after super.init, if required
        self.backgroundColor = .black
        self.layer.opacity = 0
        self.layer.shadowColor = UIColor.red.cgColor
        self.layer.shadowOpacity = 1.0
        self.layer.shadowRadius = 16.0
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

public class HarmViewController: AUViewController {
        
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
                    self.connectViewWithAU()
                }
            }
        }
    }
    
    var keycenterParameter: AUParameter?
    var inversionParameter: AUParameter?
    var autoParameter: AUParameter?
    var midiParameter: AUParameter?
    var triadParameter: AUParameter?
    
    var parameterObserverToken: AUParameterObserverToken?
    
    let n_qual: Int = 3
    let n_keys: Int = 12
    
    var pollTimer: Timer = Timer()

    func keyboardTouch(sender: HarmButton) {
        print("touched \(sender.keycenter)")
        sender.isSelected = true
        
        for case let b as HarmButton in view.subviews {
            if b.keycenter != sender.keycenter {
                b.isSelected = false
            }
        }
        
        keycenterParameter!.value = Float(sender.keycenter)
    }
    
    func auPoller(T: Float){
        pollTimer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(pollAudioUnit), userInfo: nil, repeats: true)
    }
    
    func pollAudioUnit()
    {
        guard let audioUnit = audioUnit else { return }
        let note = audioUnit.getCurrentNote()
        
        for v in view.subviews.flatMap({$0 as? KeyglowView}) {
            if v.keycenter == Int(note + 0.5) && note != -1 {
                v.layer.opacity = 1.0
            }
            else
            {
                v.layer.opacity = 0.0
            }
        }
        
//        let b: HarmButton = view.viewWithTag(Int(keycenterParameter!.value) + 1) as! HarmButton
//        b.sendActions(for: .touchDown)
        return
    }
    
    public override func viewDidLoad()
    {
        view.backgroundColor = UIColor.black
        let hview: HarmView = view as! HarmView
        
        for k in 0...n_keys-1 {
            let v = KeyglowView()
            v.keycenter = k
            hview.addSubview(v)
        }
        
        for q in 0...n_qual-1 {
            for k in 0...n_keys-1 {
                let btn: HarmButton = HarmButton()
                
                btn.setTitle("\(k+q*n_keys+1)", for: UIControlState())
                btn.setTitleColor(.black, for: UIControlState())
                btn.backgroundColor = .white
                
                if ([1,3,6,8,10].contains(k)) {
                    btn.setTitleColor(.white, for: UIControlState())
                    btn.backgroundColor = .black
                }
                
                btn.addTarget(self, action: #selector(keyboardTouch), for: [.touchDown,.touchDragEnter])
                btn.tag = k+q*n_keys+1
                btn.keycenter = k+q*n_keys
                view.addSubview(btn)
            }
        }
        
        auPoller(T: 0.05)
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
        autoParameter = paramTree.value(forKey: "auto") as? AUParameter
        midiParameter = paramTree.value(forKey: "midi") as? AUParameter
        triadParameter = paramTree.value(forKey: "triad") as? AUParameter
        
        let b: HarmButton = view.viewWithTag(Int(keycenterParameter!.value) + 1) as! HarmButton
        b.isSelected = true
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            //guard let strongSelf = self else { return }
            
            print("address = \(address)")
            print("value = \(value)")
        })
    }
}
