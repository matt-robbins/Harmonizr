//
//  PresetFavoriteViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 3/23/18.
//

import UIKit

class PresetFavoriteViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presetController!.presets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = presetController!.presets[indexPath.row].name
        return cell
    }
    
    public func tableView(_ tableView: UITableView,
                          titleForHeaderInSection section: Int) -> String? {
        return "Presets"
    }
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var presetTable: UITableView!
    
    @IBOutlet weak var navBar: UINavigationBar!
    
    var presetController: PresetController?
    var favIx: Int = 0
    
    var doneFcn: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presetTable.delegate = self
        presetTable.dataSource = self
        
        
        navBar.topItem?.title = "Favorite Preset \"f\(favIx + 1)\""
        
        presetController = PresetController()
        presetController!.loadPresets()
        
        //presetPicker.selectRow(favIx, inComponent: 0, animated: true)
        let indexPath = IndexPath(row: favIx, section: 0)
        presetTable.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
        
        presetTable.tableFooterView = UIView()
        // Do any additional setup after loading the view.
    }

    @IBAction func done(_ sender: Any) {
        let row = presetTable.indexPathForSelectedRow?.row
        presetController?.favorites[favIx] = row!
        presetController?.storePresets()
        doneFcn!()
        self.dismiss(animated: false)
    }
}
