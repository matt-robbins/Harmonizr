//
//  ConfigDetailViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 6/20/18.
//

import UIKit

class ConfigListViewController: UITableViewController {
    
    var keycenterParameter: AUParameter?
    var inversionParameter: AUParameter?
    var nvoicesParameter: AUParameter?
    var autoParameter: AUParameter?
    var autoStrengthParameter: AUParameter?
    var midiParameter: AUParameter?
    var midiLinkParameter: AUParameter?
    var midiLegatoParameter: AUParameter?
    var triadParameter: AUParameter?
    var bypassParameter: AUParameter?
    var speedParameter: AUParameter?
    var hgainParameter: AUParameter?
    var vgainParameter: AUParameter?
    var dryMixParameter: AUParameter?
    var tuningParameter: AUParameter?
    var threshParameter: AUParameter?
    
    @IBOutlet weak var speedSlider: UISlider!
    
    @IBOutlet weak var drySwitch: UISwitch!
    @IBOutlet weak var legatoSwitch: UISwitch!
    
    
    @IBOutlet weak var threshStepper: UIStepper!
    
    @IBOutlet weak var threshLabel: UILabel!
    
    @IBOutlet weak var levelStepper: UIStepper!
    @IBOutlet weak var levelLabel: UILabel!
    
    @IBOutlet weak var corrStepper: UIStepper!
    @IBOutlet weak var corrLabel: UILabel!
    
    @IBOutlet weak var tuningLabel: UILabel!
    
    @IBOutlet weak var showKeyboardSwitch: UISwitch!
    
    var defaults: UserDefaults?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let paramTree = globalAudioUnit?.parameterTree else { return }
        
        keycenterParameter = paramTree.value(forKey: "keycenter") as? AUParameter
        inversionParameter = paramTree.value(forKey: "inversion") as? AUParameter
        nvoicesParameter = paramTree.value(forKey: "nvoices") as? AUParameter
        autoParameter = paramTree.value(forKey: "auto") as? AUParameter
        autoStrengthParameter = paramTree.value(forKey: "auto_strength") as? AUParameter
        midiParameter = paramTree.value(forKey: "midi") as? AUParameter
        midiLinkParameter = paramTree.value(forKey: "midi_link") as? AUParameter
        midiLegatoParameter = paramTree.value(forKey: "midi_legato") as? AUParameter
        triadParameter = paramTree.value(forKey: "triad") as? AUParameter
        bypassParameter = paramTree.value(forKey: "bypass") as? AUParameter
        speedParameter = paramTree.value(forKey: "speed") as? AUParameter
        hgainParameter = paramTree.value(forKey: "h_gain") as? AUParameter
        vgainParameter = paramTree.value(forKey: "v_gain") as? AUParameter
        dryMixParameter = paramTree.value(forKey: "dry_mix") as? AUParameter
        
        tuningParameter = paramTree.value(forKey: "tuning") as? AUParameter
        threshParameter = paramTree.value(forKey: "threshold") as? AUParameter
        
        threshLabel.text = "\(threshParameter!.value)"
        
        tuningLabel.text = "\(tuningParameter!.value) Hz"
        
        corrStepper.value = Double(autoStrengthParameter!.value * 100)
        corrLabel.text = "\(Int(corrStepper.value)) %"
        
        levelStepper.value = Double(hgainParameter!.value * 100)
        levelLabel.text = "\(Int(levelStepper.value)) %"
        
        drySwitch.isOn = dryMixParameter!.value > 0.5
        legatoSwitch.isOn = midiLegatoParameter!.value > 0.5
        
        speedSlider.value = speedParameter!.value
        
        defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        showKeyboardSwitch.isOn = (defaults?.bool(forKey: "showMidiKeyboard"))!
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section == 0)
        {
            if (indexPath.row == 0)
            {
                self.performSegue(withIdentifier: "showHarmony", sender: self)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        print("accessory: \(indexPath)")
    }
    @IBAction func drySwitch(_ sender: UISwitch) {
        dryMixParameter!.value = sender.isOn ? 1 : 0
    }
    
    @IBAction func legatoSwitch(_ sender: UISwitch) {
        midiLegatoParameter!.value = sender.isOn ? 1 : 0
    }
    
    @IBAction func harmonyLevel(_ sender: UIStepper) {
        hgainParameter!.value = AUValue(sender.value / 100)
        levelLabel.text = "\(Int(sender.value))%"
    }
    @IBAction func corrStrength(_ sender: UIStepper) {
        autoStrengthParameter!.value = AUValue(sender.value / 100)
        corrLabel.text = "\(Int(sender.value)) %"
    }
    @IBAction func baseTuning(_ sender: UIStepper) {
        tuningParameter!.value = AUValue(sender.value)
        
        tuningLabel.text = "\(tuningParameter!.value) Hz"
    }
    @IBAction func setThreshold(_ sender: UIStepper) {
        threshParameter!.value = AUValue(sender.value)
        threshLabel.text = "\(threshParameter!.value)"
    }
    @IBAction func setSpeed(_ sender: UISlider) {
        speedParameter!.value = AUValue(sender.value)
    }
    @IBAction func toggleKeyboard(_ sender: UISwitch) {
        
        defaults?.set(sender.isOn, forKey: "showMidiKeyboard")
    }
}


class ConfigDetailViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
