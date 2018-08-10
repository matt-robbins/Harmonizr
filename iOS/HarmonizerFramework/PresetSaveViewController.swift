//
//  PresetSaveViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 7/17/18.
//

import UIKit

class PresetSaveViewController: UIViewController {
    
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var presetTable: UITableView!
    
    var presetNeedsSave: Bool = false
    var presetIx: Int = 0
    
    var presetController: PresetController? {
        didSet {
            presetIx = presetController!.presetIx
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        presetTable.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        presetTable.dataSource = self
        presetTable.delegate = self
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
    
    @IBAction func newPreset(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "New Preset", message: "Add new preset", preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) {
            [unowned self] action in
            
            guard let textField = alert.textFields?.first,
                let nameToSave = textField.text else {
                    return
            }
            
            self.presetController!.appendPreset()
            self.presetIx = self.presetController!.presets.count - 1
            self.presetController!.writePreset(name: nameToSave, ix: self.presetIx)
            self.navigationController!.popViewController(animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default)
        
        alert.addTextField()
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
    }

}

extension PresetSaveViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        //updateSelection()
        return presetController!.presets.filter { $0.isFactory == false }.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let p = presetController!.presets.filter { $0.isFactory == false }[indexPath.row]
        
        cell.textLabel?.text = p.name! + (p.isFactory ? " (factory)" : "")
        cell.textLabel?.textColor = UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor
        
        cell.isUserInteractionEnabled = !p.isFactory
        
        return cell
    }
}
extension PresetSaveViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let p = presetController!.presets.filter { $0.isFactory == false }[indexPath.row]
        if (p.isFactory)
        {
            return
        }
        
        presetController!.writePreset(name: p.name!, ix: p.id)
        navigationController!.popViewController(animated: true)
    }
}
