//
//  Untitled.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 4/14/26.
//

//
//  MidiSettingsTableViewController.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 2/27/19.
//

import UIKit

class AuPresetTableViewController: UITableViewController {
    
    var audioUnit: AUAudioUnit?
    var presets:[AUAudioUnitPreset]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        presets = audioUnit?.factoryPresets
        self.tableView!.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 1))
        self.tableView!.register(UITableViewCell.self, forCellReuseIdentifier: "basic")
    }

    // MARK: - Table view data source
    
    // Create a standard header that includes the returned text.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection
                                section: Int) -> String? {
        return nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows

        return presets?.count ?? 0
 
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
        cell.textLabel?.text = presets?[indexPath.row].name
        
        cell.accessoryType = (audioUnit?.currentPreset?.name == presets?[indexPath.row].name) ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //values[indexPath.row] = !values[indexPath.row]
        
        audioUnit?.currentPreset = presets?[indexPath.row]
        self.tableView.reloadData()
    }
    
}
