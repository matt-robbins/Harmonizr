//
//  MidiSettingsTableViewController.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 2/27/19.
//

import UIKit

class AuSettingsTableViewController: UITableViewController {
    
    var settings = [String]()
    var presets:[AUAudioUnitPreset]?
    
    var audioUnit: AUAudioUnit?
    var paramTree: AUParameterTree?
    
    var sections = ["Settings","Presets"]
    
    func showPresets(_ show: Bool)
    {
        sections = show ? ["Settings","Presets"] : ["Settings"]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        paramTree = audioUnit?.parameterTree
        presets = audioUnit?.factoryPresets
        //settings = []
        if (settings.count == 0)
        {
            settings = paramTree?.allParameters.map{ $0.identifier } ?? []
        }
        self.tableView!.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 1))
        
        self.tableView!.register(UITableViewCell.self, forCellReuseIdentifier: "basic")
    }

    // MARK: - Table view data source
    
    // Create a standard header that includes the returned text.
    override func tableView(_ tableView: UITableView, titleForHeaderInSection
                                section: Int) -> String? {
        if (sections.count < 2)
        {
            return nil
        }
        return sections[section]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        switch (sections[section])
        {
        case "Settings":
            return settings.count
        case "Presets":
            return presets?.count ?? 0
        default:
            return 0
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if (sections[indexPath.section] == "Settings")
        {
            var param = paramTree?.value(forKey: settings[indexPath.row]) as? AUParameter
            if (param == nil)
            {
                param = paramTree?.allParameters.filter{ $0.identifier == settings[indexPath.row] }.first
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "auparameter", for: indexPath) as! AuParameterTableViewCell
            
            cell.param = param
            cell.parentTable = self.tableView
            cell.selectionStyle = .none
            return cell
        }
        else
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
            cell.textLabel?.text = presets?[indexPath.row].name
            
            cell.accessoryType = (audioUnit?.currentPreset?.name == presets?[indexPath.row].name) ? .checkmark : .none
            cell.selectionStyle = .none
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //values[indexPath.row] = !values[indexPath.row]
        
        if (sections[indexPath.section] == "Presets")
        {
            audioUnit?.currentPreset = presets?[indexPath.row]
            self.tableView.reloadData()
        }
        
    }
    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
