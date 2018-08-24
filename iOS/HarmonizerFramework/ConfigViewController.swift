//
//  ConfigViewController.swift
//  iOSFilterDemoFramework
//
//  Created by Matthew E Robbins on 11/1/17.
//

import Foundation
import UIKit
import AudioToolbox

protocol PresetSaveDelegate: class {
    func configViewControllerGetPresetIx(_ controller: ConfigViewController) -> Int
    func configViewControllerGetPresets(_ controller: ConfigViewController) -> [String]
}

protocol KeyboardEditorDelegate: class {
    func keyboardEditor(_ view: KeyboardEditorView, setVoice index: Int, note: Int)
}

class KeyboardEditorView: KeyboardView {
    var xpos: CGFloat = -1.0
    var curr_note: Int = -1
    var base_note: Int = 60 {
        didSet {
            keys[base_note].isSelected = true
        }
    }
    
    weak var editorDelegate: KeyboardEditorDelegate?
    
    var harm_colors = [UIColor.red.cgColor, UIColor.yellow.cgColor, UIColor.yellow.cgColor, UIColor.yellow.cgColor]
    var harm_voices: Array<Int> = []
    {
        didSet {
            if (harm_voices.count == 0) { return }
            
            CATransaction.begin()
            
            for k in keys {
                k.isHarm = false
                k.isSelected = false
            }
            
            for ix in 0...harm_voices.count-1 {
                keys[harm_voices[ix]].toggleActive(true, color: harm_colors[ix])
            }
            
            keys[base_note].isSelected = true
            
             CATransaction.commit()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        labels = false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        xpos = (touches.first?.location(in:self).x)!
        
        let key = containerLayer.hitTest((touches.first?.location(in:self))!) as? Key
        if (key != nil)
        {
            let ix = harm_voices.index(of: key!.midinote)

            if (ix != nil)
            {
                curr_note = ix!
                key!.borderColor = harm_colors[curr_note]
            }
        }
        return
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        calculate_movement(touches,true)
        let key = containerLayer.hitTest((touches.first?.location(in:self))!) as? Key
        let old_key = containerLayer.hitTest((touches.first?.previousLocation(in:self))!) as? Key
        if (key != nil && old_key != nil && key != old_key && curr_note >= 0)
        {
            harm_voices[curr_note] = key!.midinote
            old_key!.borderColor = UIColor.darkGray.cgColor
            key!.borderColor = harm_colors[curr_note]
            if (editorDelegate != nil)
            {
                editorDelegate?.keyboardEditor(self, setVoice: curr_note, note: key!.midinote - base_note)
            }
        }
        return
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        calculate_movement(touches,false)
        
        for key in keys {
            key.borderColor = UIColor.darkGray.cgColor
        }
        curr_note = -1
        return
    }
}

protocol HarmonizerAlternateViewDelegate: class {
    func ShowMainView()
}

public class ConfigViewController: UIViewController, UITextFieldDelegate,
    KeyboardViewDelegate, KeyboardEditorDelegate, VoicesViewDelegate
{
    //MARK: Properties
    
    @IBOutlet weak var qualityStack: UIStackView!
    @IBOutlet weak var degreeStack: UIStackView!
    
    @IBOutlet weak var qualitySeg: UISegmentedControl!
    

    @IBOutlet weak var rootStack: UIStackView!
    
    @IBOutlet weak var rootLabel: UILabel!
    @IBOutlet weak var rootStepper: UIStepper!
    
    @IBOutlet weak var degreeStepper: UIStepper!
    @IBOutlet weak var degreeLabel: UILabel!
    
    @IBOutlet weak var liveSwitch: UISwitch!
    
    @IBOutlet weak var fixedIntervalSwitch: UISwitch!
    
    @IBOutlet weak var voicesView: HarmonizerVoicesView!
    @IBOutlet weak var keyboardView: KeyboardEditorView!
    var preset: Preset?
    
    weak var delegate: HarmonizerAlternateViewDelegate?
    
    var doneFcn: (() -> Void)?
    
    var presetIx: Int = 0
    var presetController: PresetController? {
        didSet {
            presetIx = presetController!.presetIx
        }
    }
    
    var keynames = ["C", "C\u{266f}/D\u{266D}", "D", "D\u{266f}/E\u{266D}", "E", "F", "F\u{266f}/G\u{266D}","G", "G\u{266f}/A\u{266D}", "A", "B\u{266D}", "B/C\u{266D}"]
    var degreenames = ["1", "\u{266f}1", "2", "\u{266f}2", "3", "4", "\u{266f}4","5", "\u{266D}6", "6", "\u{266D}7", "7"]
    var currInterval = 0
    
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            //print("set audio unit in config view controller!")
            paramTree = audioUnit!.parameterTree
            let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
            let inversionParam = paramTree!.value(forKey: "inversion") as? AUParameter
            let nvoicesParam = paramTree!.value(forKey: "nvoices") as? AUParameter
            let triadParam = paramTree!.value(forKey: "triad") as? AUParameter
            
            voicesView.setSelectedVoices(Int(nvoicesParam!.value), inversion: Int(inversionParam!.value))
            let keycenter = keycenterParam!.value
            
            fixedIntervalSwitch.isOn = triadParam!.value >= 0
            setFixedInterval(fixedIntervalSwitch.isOn)
            
            keyQuality = Int(keycenter / 12)
            keyRoot = Int(keycenter) % 12
            //qualitySeg.selectedSegmentIndex = keyQuality
            
            //let buttons = rootStack.arrangedSubviews as! [HarmButton]
//            for c in 0...buttons.count - 1
//            {
//                buttons[c].isSelected = (c == keyRoot)
//            }
            
            drawKeys()
            //rootStepper!.value = Double(keyRoot)
            
            //rootLabel!.text = keynames[keyRoot]
            
            refresh()
            //
        }
    }
    
    var presetNeedsSave: Bool = false {
        didSet {
            
        }
    }
    
    var paramTree: AUParameterTree?
    
    var keyQuality = 0
    var keyRoot = 0
    var scaleDegree = 0
    var unisonOffset = 128
    var maxOffset = 128
    var nc = 4
    
    var timer = Timer()
    
    func keyboardEditor(_ view: KeyboardEditorView, setVoice index: Int, note: Int) {
        let key = "interval_\(nc*scaleDegree + index + keyQuality*12*nc)"
        let param = paramTree!.value(forKey: key) as? AUParameter
        let inv_param = paramTree!.value(forKey: "inversion") as? AUParameter
        //print("hi! \(index) -> \(note)")
        
        var offset = Float(note)
        
        if (index > Int((inv_param?.value)!)) {
            offset += 12
        }
        
        param!.value = offset
    }
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeInversion inversion: Float) {
        let param = paramTree!.value(forKey: "inversion") as? AUParameter
        param!.value = inversion
        drawKeys()
    }
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeNvoices voices: Float) {
        let param = paramTree!.value(forKey: "nvoices") as? AUParameter
        param!.value = voices
    }
    
    
    func keyboardView(_ view: KeyboardView, noteOn note: Int) {
        return
    }
    
    func keyboardView(_ view: KeyboardView, noteOff note: Int) {
        return
    }
    
    func auPoller(T: Float){
        // Scheduling timer to Call the timerFunction
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
    }
    
    @objc func timerFunction()
    {
        guard let audioUnit = audioUnit else { return }
        
        if (self.view.isHidden)
        {
            return
        }
        
        let note = audioUnit.getCurrentNote()
        let notes = audioUnit.getNotes()
        
        var int_notes: [Int] = [Int]()
        
        for n in notes! {
            int_notes.append((n as? Int)!)
        }
        
        keyboardView.setCurrentNote(int_notes)
        
        if (note == -1.0)
        {
            currInterval = -1
        }
        else
        {
            let i = Int(round(note)) % 12
            let k = Int(audioUnit.getCurrentKeycenter()) % 12
            
            currInterval = (i - k + 12) % 12
            
//            if (liveSwitch!.isOn && currInterval != scaleDegree)
//            {
//                scaleDegree = currInterval
//
//                degreeStepper!.value = Double(scaleDegree)
//                refresh()
//                drawKeys()
//            }
        }
        
        return
    }
        
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = "Edit Harmony"
        keyboardView.delegate = self
        keyboardView.editorDelegate = self
        //keyboardView.n_visible = 21
        voicesView.delegate = self
        
        liveSwitch!.onTintColor = self.view.tintColor
        
        audioUnit = globalAudioUnit
        
//        let d = degreeStack.arrangedSubviews[0] as! HarmButton
//        d.isSelected = true

//        pickerData = ["-12","-11","-10","-9","-8","-7","-6","-5","-M3","-m3","-M2","-m2","U","m2","M2","m3","M3","P4","d5","P5","m6","M6","m7","M7","P8","m9","M9","m10","M10"]
//
//        pickerData = ["-12","-11","-10","-9","-8","-7","-6","-5","-4","-3","-2","-1","0",
//                      "+1","+2","+3","+4","+5","+6","+7","+8","+9","+10","+11","+12","+13","+14","+15","+16"]
        
        rootLabel!.text = keynames[0]
        degreeLabel!.text = degreenames[0]
//
        degreeStepper!.maximumValue = 11
        degreeStepper!.minimumValue = 0
        degreeStepper!.stepValue = 1
        degreeStepper!.wraps = true
        rootStepper!.maximumValue = 11
        rootStepper!.minimumValue = 0
        rootStepper!.stepValue = 1
        rootStepper!.wraps = true
        
        drawKeys()
        refresh()
        
    }
    
    public override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        auPoller(T: 0.1)
    }
    
    public override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    public func drawKeys()
    {
        keyboardView.base_note = 60 + (keyRoot + scaleDegree) % 12
        
        keyboardView.harm_voices = []
        
        var harm_voices: Array<Int> = []
        
        for k in 0...nc-1
        {
            let key = "interval_\(nc*scaleDegree + k + keyQuality*12*nc)"
            var param = paramTree!.value(forKey: key) as? AUParameter
            var offset = Int(param!.value)
            
            param = paramTree!.value(forKey: "inversion") as? AUParameter
            let inversion = Int(param!.value)

            if (k > inversion)
            {
                offset -= 12
            }
            
            harm_voices.append(60 + offset + (keyRoot + scaleDegree) % 12)
        }
        
        keyboardView.harm_voices = harm_voices
    }
    
    public func refresh()
    {
        guard audioUnit != nil else { return }
        
        keyQuality = qualitySeg.selectedSegmentIndex
        //qualitySeg!.selectedSegmentIndex = keyQuality
        
        let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        keycenterParam!.value = Float(keyQuality * 12 + keyRoot)
        
        for k in keyboardView.keys
        {
            if (k.midinote) == 60 + (keyRoot + scaleDegree) % 12
            {
                keyboardView.keyOffset = Int(k.midinote * 7/12) - 3
            }
        }
        
        rootLabel!.text = keynames[keyRoot]
        degreeLabel!.text = degreenames[scaleDegree]
        
//        for k in 0...nc-1
//        {
//            let key = "interval_\(nc*scaleDegree + k + keyQuality*12*nc)"
//            let param = paramTree!.value(forKey: key) as? AUParameter
//            let offset = Int(param!.value)
//
////            for k in keyboardView.keys
////            {
////                if (k.midinote) == 60 + offset + (keyRoot + scaleDegree) % 12
////                {
////
////                    k.isHarm = true
////                }
////            }
//
//            //intervalPicker!.selectRow(offset+unisonOffset, inComponent: k, animated: true)
//        }
    }
    
    //MARK: Actions
    @IBAction func done(_ sender: UIButton?)
    {

        if (doneFcn != nil)
        {
            doneFcn!()
        }
//        self.view.removeFromSuperview()
//        self.removeFromParentViewController()
        delegate?.ShowMainView()
        
        //self.view.isHidden = true
        sender!.isSelected = false
        //self.dismiss(animated: true, completion: { sender!.isSelected = false })
    }
    
    @IBAction func setQuality(_ sender: UISegmentedControl?)
    {
        refresh()
        drawKeys()
    }
    @IBAction func rootInc(_ sender: UIStepper) {
        keyRoot = Int(sender.value)
        
        refresh()
        drawKeys()
    }
    
    @IBAction func degreeInc(_ sender: UIStepper) {
        scaleDegree = Int(sender.value)
        
        refresh()
        drawKeys()
    }
    
    func setFixedInterval(_ fixed: Bool)
    {
        qualitySeg!.isEnabled = !fixed
        qualityStack!.isHidden = fixed
        degreeStack!.isHidden = fixed
        
    }
    
    @IBAction func fixedIntervalSet(_ sender: UISwitch) {
        setFixedInterval(sender.isOn)
        let param = paramTree!.value(forKey: "triad") as? AUParameter
        let val: AUValue = sender.isOn ? 0 : -1
        param!.value = val
    }
    
    @IBAction func setRoot(_ sender: HarmButton?)
    {
        let colors = [0,1,0,1,0,0,1,0,1,0,1,0]
        //let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        var r = 0
        for b in rootStack.arrangedSubviews as! [HarmButton]
        {
            if (b == sender)
            {
                keyRoot = r
                b.isSelected = true
            }
            else
            {
                b.isSelected = false
            }
            r = r + 1
        }
        
        var ix = 0
        for b in degreeStack.arrangedSubviews as! [HarmButton]
        {
            b.backgroundColor = colors[(ix + keyRoot) % 12] == 1 ? UIColor.black : UIColor.white
            b.configure()
            if (ix == scaleDegree)
            {
                b.isSelected = true
            }
            ix += 1
            
        }
        refresh()
        drawKeys()

    }
    
    @IBAction func setDegree(_ sender: HarmButton?)
    {
        var degree = 0
        for b in degreeStack.arrangedSubviews as! [HarmButton]
        {
            if (b == sender)
            {
                scaleDegree = degree
                b.isSelected = true
            }
            else
            {
                b.isSelected = false
            }
            degree = degree + 1
        }
        
        refresh()
        drawKeys()
    }
    
}
