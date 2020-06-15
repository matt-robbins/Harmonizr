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

        //presetTable.register(HarmTableViewCell.self, forCellReuseIdentifier: "Cell")
        presetTable.dataSource = self
        presetTable.delegate = self
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        presetTable.selectRow(at: IndexPath(row: presetController!.presetIx, section: 0), animated: false, scrollPosition: UITableViewScrollPosition.top)
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
        presetTable.selectRow(at: IndexPath(row: presetController!.presetIx, section: 0), animated: true, scrollPosition: .top)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "presetListCell", for: indexPath)
        
        let p = presetController!.presets[indexPath.row]
        
        cell.textLabel?.text = p.name! + (p.factoryId >= 0 ? " (factory)" : "")
        //cell.textLabel?.textColor = UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor
        cell.selectionStyle = p.factoryId >= 0 ? .default : .none
        //cell.accessoryView = UISwitch()
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete)
        {
            presetController!.delete(ix: indexPath.row)
            self.presetTable.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        updateSelection()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (tableView.isEditing == false)
        {
            presetController!.selectPreset(preset: indexPath.row)
            self.navigationController!.popViewController(animated: true)
            //return
        }
        
        let p = presetController!.presets[indexPath.row]
        
        if (p.factoryId >= 0)
        {
            return
        }
        
        let alert = UIAlertController(title: "Rename Preset", message: "Rename this preset", preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) {
            [unowned self] action in
            
            guard let textField = alert.textFields?.first,
                let nameToSave = textField.text else {
                    return
            }
            
            self.presetController!.presets[indexPath.row].name = nameToSave
            self.presetController!.storePresets()
            self.presetTable.reloadData()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default)
        
        alert.addTextField()
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        presetController!.swap(src: sourceIndexPath.row, dst: destinationIndexPath.row)
    }
}

extension PresetListViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return presetController!.presets[indexPath.row].factoryId >= 0 ? .none : .delete
    }
}
