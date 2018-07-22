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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        presetController?.favorites[favIx] = row
        presetController?.storePresets()
    }
    
    public func tableView(_ tableView: UITableView,
                          titleForHeaderInSection section: Int) -> String? {
        return "Presets"
    }
    
   // @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var presetTable: UITableView!
    
    var presetController: PresetController?
    var favIx: Int = 0
    
    var doneFcn: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presetTable.delegate = self
        presetTable.dataSource = self
        
        title = "Favorite Preset \"f\(favIx + 1)\""
        
        presetController = PresetController()
        presetController!.loadPresets()
        
        let indexPath = IndexPath(row: presetController!.favorites[favIx], section: 0)
        presetTable.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
        
        presetTable.tableFooterView = UIView()
        // Do any additional setup after loading the view.
    }
}
