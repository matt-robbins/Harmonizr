//
//  MidiSettingsTableViewController.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 2/27/19.
//

import UIKit

class MidiSettingsTableViewController: UITableViewController {
    
    let settings = ["keycenter_cc", "keycenter_cc_offset","keyquality_cc", "keyquality_cc_offset", "nvoices_cc","inversion_cc","midi_rx_pc", "midi_tx_harm","midi_tx_mel"]
    
    var paramTree: AUParameterTree?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        paramTree = globalAudioUnit?.parameterTree
        self.tableView!.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 1))
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return settings.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let param = paramTree?.value(forKey: settings[indexPath.row]) as? AUParameter
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "midisetting", for: indexPath) as! MidiSettingsTableViewCell
        cell.param = param
        cell.parentTable = self.tableView
        return cell
        
//        else
//        {
//            let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)
//            cell.textLabel?.text = settings[indexPath.row]
//            cell.accessoryType = false ?? false ? .checkmark : .none
//            return cell
//        }
        
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //values[indexPath.row] = !values[indexPath.row]
        
//        if (types[indexPath.row] == "bool")
//        {
//            let val = defaults?.bool(forKey:defaultNames[indexPath.row]) ?? false
//            defaults?.set(!val, forKey:defaultNames[indexPath.row])
//            self.tableView.reloadData()
//        }
        
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
