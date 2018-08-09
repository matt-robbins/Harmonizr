//
//  PresetListViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 8/8/18.
//

import UIKit

class PresetListViewController: UIViewController {

    @IBOutlet weak var presetTable: UITableView!
    
    var presetController: PresetController? {
        didSet {
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        presetTable.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        presetTable.dataSource = self
        presetTable.delegate = self
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addPreset(_ sender: UIBarButtonItem) {
    }
    @IBAction func toggleEdit(_ sender: UIBarButtonItem) {
        presetTable.isEditing = !presetTable.isEditing
        
        sender.title? = presetTable.isEditing ? "Done" : "Edit"
        if (!presetTable.isEditing)
        {
            updateSelection()
        }
    }
    
    func updateSelection()
    {
        
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

extension PresetListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        //updateSelection()
        return presetController!.presets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let p = presetController!.presets[indexPath.row]
        
        cell.textLabel?.text = p.name! + (p.isFactory ? " (factory)" : "")
        cell.textLabel?.textColor = UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor
                
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete)
        {
            print("delete!")
            presetController!.delete(ix: indexPath.row)
            self.presetTable.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        updateSelection()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presetController!.selectPreset(preset: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        presetController!.swap(ix1: sourceIndexPath.row, ix2: destinationIndexPath.row)
    }
}

extension PresetListViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return presetController!.presets[indexPath.row].isFactory ? .none : .delete
    }
}
