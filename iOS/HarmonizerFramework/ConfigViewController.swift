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

public class ConfigViewController: UIViewController, UITableViewDelegate, UITableViewDataSource,
    KeyboardViewDelegate, KeyboardEditorDelegate, VoicesViewDelegate
{
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        
        switch (indexPath.row)
        {
        case 0:
            
            cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
            cell?.textLabel?.text = "Fixed Intervals"
            
            let sw = cell?.viewWithTag(101) as! UISwitch
            sw.isOn = triadParam!.value >= 0
            sw.addTarget(self,action: #selector(self.fixedIntervalSet(_:)), for: .valueChanged)
            
        case 1:
            
            let quality = Int(keycenterParam!.value / 12)
            
            cell = tableView.dequeueReusableCell(withIdentifier: "SegmentCell", for: indexPath)
            
            cell?.textLabel?.text = "Key Quality"
            
            let seg = cell?.viewWithTag(100) as! UISegmentedControl
            seg.selectedSegmentIndex = quality
            
            cell?.textLabel?.isEnabled = !fixedIntervals
            seg.isEnabled = !fixedIntervals
            
            seg.addTarget(self,action: #selector(self.setQuality(_:)), for: .valueChanged)
            
        case 2:
            cell = tableView.dequeueReusableCell(withIdentifier: "StepperCell", for: indexPath)
            
            cell?.textLabel?.text = "Scale Degree"
            cell?.textLabel?.isEnabled = !fixedIntervals
            
            let stepper = cell?.viewWithTag(102) as! UIStepper
            stepper.maximumValue = 11
            stepper.stepValue = 1
            stepper.value = Double(scaleDegree)
            degreeLabel = cell?.viewWithTag(101) as? UILabel
            degreeLabel.text = "\(degreenames[scaleDegree])"
            
            cell?.textLabel?.isEnabled = !fixedIntervals
            degreeLabel.isEnabled = !fixedIntervals
            stepper.isEnabled = !fixedIntervals
            stepper.alpha = fixedIntervals ? 0.5 : 1
            
            stepper.addTarget(self, action: #selector(self.degreeInc(_:)), for: .valueChanged)
            
        case 3:
            cell = tableView.dequeueReusableCell(withIdentifier: "StepperCell", for: indexPath)
            
            cell?.textLabel?.text = "Show/Hear with Key Root"
            
            rootLabel = cell?.viewWithTag(101) as? UILabel
            rootLabel.text = "\(keynames[keyRoot])"
            
            let stepper = cell?.viewWithTag(102) as! UIStepper
            stepper.maximumValue = 11
            stepper.stepValue = 1
            stepper.value = Double(keyRoot)
            
            cell?.textLabel?.isEnabled = !fixedIntervals
            rootLabel.isEnabled = !fixedIntervals
            stepper.isEnabled = !fixedIntervals
            stepper.alpha = fixedIntervals ? 0.5 : 1
            
            stepper.addTarget(self, action: #selector(self.rootInc(_:)), for: .valueChanged)
            
        case 4:
            cell = tableView.dequeueReusableCell(withIdentifier: "StepperCell", for: indexPath)
            
            cell?.textLabel?.text = "Inversion"
            
            inversionLabel = cell?.viewWithTag(101) as? UILabel
            inversionLabel?.text = ""
            
            let stepper = cell?.viewWithTag(102) as! UIStepper
            stepper.maximumValue = 3
            stepper.stepValue = 1
            stepper.value = Double(inversion)
            
            stepper.addTarget(self, action: #selector(self.setInversion(_:)), for: .valueChanged)
            
        default:
            cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell?.textLabel?.text = "row \(indexPath.row)"
        }
        
        cell?.textLabel?.textColor = UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor
        
        cell?.selectionStyle = .none
        return cell!
       
    }
    
    //MARK: Properties
    
    @IBOutlet weak var configTable: UITableView!
    
    weak var rootLabel: UILabel!
    weak var degreeLabel: UILabel!
    weak var inversionLabel: UILabel?
    
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
    
    var presetNeedsSave: Bool = false {
        didSet {
            
        }
    }
    
    var paramTree: AUParameterTree?
    var keycenterParam: AUParameter?
    var inversionParam: AUParameter?
    var nvoicesParam: AUParameter?
    var triadParam: AUParameter?
    
    
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            //print("set audio unit in config view controller!")
            paramTree = audioUnit!.parameterTree
            keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
            inversionParam = paramTree!.value(forKey: "inversion") as? AUParameter
            nvoicesParam = paramTree!.value(forKey: "nvoices") as? AUParameter
            triadParam = paramTree!.value(forKey: "triad") as? AUParameter
            
            //voicesView.setSelectedVoices(Int(nvoicesParam!.value), inversion: Int(inversionParam!.value))
            let keycenter = keycenterParam!.value
            
            fixedIntervals = Float((triadParam?.value)!) >= 0
            
            keyQuality = Int(keycenter / 12)
            keyRoot = Int(keycenter) % 12
            inversion = Int(inversionParam!.value)
            
            drawKeys()
            
            refresh()
            //
        }
    }
    
    var keyQuality = 0
    var keyRoot = 0
    var inversion = 0
    var fixedIntervals = false
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
        }
        
        return
    }
        
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = "Edit Harmony"
        keyboardView.delegate = self
        keyboardView.editorDelegate = self
        keyboardView.n_visible = 28
        //keyboardView.keyOffset = 14
        //voicesView.delegate = self
        
        audioUnit = globalAudioUnit
        
        configTable.delegate = self
        configTable.dataSource = self
        configTable.tableFooterView = UIView()
        
//        drawKeys()
//        refresh()
        
    }
    
    public override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        refresh()
        drawKeys()
        auPoller(T: 0.1)
    }
    
    public override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    public func drawKeys()
    {
        keyboardView.base_note = 48 + (keyRoot + scaleDegree) % 12
        
        keyboardView.harm_voices = []
        
        var harm_voices: Array<Int> = []
        
        for k in 0...nc-1
        {
            let key = "interval_\(nc*scaleDegree + k + keyQuality*12*nc)"
            let param = paramTree!.value(forKey: key) as? AUParameter
            var offset = Int(param!.value)
            
            let inversion = Int(inversionParam!.value)

            if (k > inversion)
            {
                offset -= 12
            }
            
            harm_voices.append(48 + offset + (keyRoot + scaleDegree) % 12)
        }
        
        keyboardView.harm_voices = harm_voices
    }
    
    public func refresh()
    {
        guard audioUnit != nil else { return }
        
        keycenterParam!.value = Float(keyQuality * 12 + keyRoot)
        
        keyboardView.keyOffset = 14
        
//        for k in keyboardView.keys
//        {
//            if (k.midinote) == 48 + (keyRoot + scaleDegree) % 12
//            {
//                keyboardView.keyOffset = 14
//            }
//        }
        if (rootLabel != nil)
        {
            rootLabel!.text = keynames[keyRoot]
        }
        if (degreeLabel != nil)
        {
            degreeLabel!.text = degreenames[scaleDegree]
        }
    }
    
    
    @IBAction func setQuality(_ sender: UISegmentedControl?)
    {
        keyQuality = (sender?.selectedSegmentIndex)!
        refresh()
        drawKeys()
    }
    @IBAction func rootInc(_ sender: UIStepper) {
        keyRoot = Int(sender.value)
        
        refresh()
        drawKeys()
    }
    
    @objc func setInversion(_ sender: UIStepper) {
        inversion = Int(sender.value)
        inversionParam!.value = AUValue(inversion)
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
//        qualitySeg!.isEnabled = !fixed
//        qualityStack!.isHidden = fixed
//        degreeStack!.isHidden = fixed
        self.fixedIntervals = fixed
        
        keycenterParam!.value = 0
        keyRoot = 0
        keyQuality = 0
        scaleDegree = 0
        self.configTable!.reloadData()
        refresh()
        drawKeys()
//
    }
    
    @IBAction func fixedIntervalSet(_ sender: UISwitch) {
        setFixedInterval(sender.isOn)
        let param = paramTree!.value(forKey: "triad") as? AUParameter
        let val: AUValue = sender.isOn ? 0 : -1
        param!.value = val
    }
}
