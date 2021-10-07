//
//  PresetListViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 8/8/18.
//

import UIKit

class PresetListViewController: UIViewController {

    @IBOutlet weak var presetTable: UITableView!
    @IBOutlet weak var marker: UIView!
    @IBOutlet var favs: [HarmButton]!
    
    var editIx = 0
    var presetController: PresetController? {
        didSet {
        }
    }
    
    var editingView: UITextField? = nil
    
    func reparentView(label: UIView) {
        let win = favs[0].window!
        for label in favs {
            
            let originalRect = label.convert(label.frame, to: win)
            label.removeFromSuperview()
            win.addSubview(label)
            //win.bringSubview(toFront: label)
            label.frame = originalRect
        }
        
        presetTable.reloadData()
        
        for ix in 0...5 {
        
            let cell = presetTable.cellForRow(at: IndexPath(row:ix, section:0)) as! PresetTableViewCell
            let dst = cell.fav!
            let label = favs[ix]
            
            UIView.animate(withDuration: 0.5, animations: {
                label.frame = (dst.convert(dst.bounds, to: win))
            }, completion: {_ in
                label.removeFromSuperview()
                dst.addSubview(label)
                label.frame = dst.bounds
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //presetTable.register(HarmTableViewCell.self, forCellReuseIdentifier: "Cell")
        
        for ix in 0...favs.count-1 {
            favs[ix].setTitle("\(ix+1)", for: .normal)
            favs[ix].setTitleColor(.black, for: .normal)
        }
        
        presetTable.dataSource = self
        presetTable.delegate = self
        presetTable.isEditing = false
        // Do any additional setup after loading the view.
        //marker.translatesAutoresizingMaskIntoConstraints = false
                
        NotificationCenter.default.addObserver(self, selector: #selector(PresetListViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PresetListViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc func keyboardWillShow(_ notification:Notification) {

        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            presetTable.contentInset = UIEdgeInsetsMake(0, 0, keyboardSize.height, 0)
        }
    }
    @objc func keyboardWillHide(_ notification:Notification) {

        if ((notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
            presetTable.contentInset = UIEdgeInsetsMake(0, 0, 0, 0)
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        presetTable.selectRow(at: IndexPath(row: presetController!.presetIx, section: 0), animated: false, scrollPosition: .none)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        reparentView(label: favs[0])
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func addPreset(_ sender: UIBarButtonItem) {
        self.presetController!.appendPreset(name: "New Preset", insert: true)
        
        let path = IndexPath(row:presetController!.presetIx,section:0)
        self.presetTable.insertRows(at:[path], with: .automatic)
        self.presetTable.reloadRows(at: [IndexPath(row:path.row+1,section:0)], with: .automatic)
        self.updateSelection()
        
        let cell = self.presetTable.cellForRow(at:path) as! PresetTableViewCell
        
        cell.selectMe()
    }
    
    @IBAction func toggleEdit(_ sender: UIBarButtonItem) {
        presetTable.isEditing = !presetTable.isEditing
        
        sender.title? = presetTable.isEditing ? "Done" : "Edit"
        if (!presetTable.isEditing)
        {
            updateSelection()
        }
    }
    
    
    func updateSelection(animated: Bool = true)
    {
        presetTable.selectRow(at: IndexPath(row: presetController!.presetIx, section: 0), animated: animated, scrollPosition: .top)
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

extension PresetListViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        //textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
        //textField.selectAll(nil)
        //textField.becomeFirstResponder()
        UIMenuController.shared.isMenuVisible = false
        editingView = textField
        updateSelection(animated: false)
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        presetController!.updatePreset(name: textField.text ?? "???", ix: textField.tag)
        textField.resignFirstResponder()
        updateSelection()
        return true
    }
    
}

extension PresetListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        //updateSelection()
        return presetController!.presets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "presetListCell2", for: indexPath) as! PresetTableViewCell
        
        let p = presetController!.presets[indexPath.row]

        cell.name.text = p.name!
        cell.name.isUserInteractionEnabled = p.factoryId < 0
        cell.name.delegate = self
        cell.name.tag = indexPath.row
        cell.name.textColor = p.factoryId < 0 ? .white : .cyan
        cell.led.power(on: indexPath.row == presetController!.presetIx)
        
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
        //updateSelection()
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        editingView?.resignFirstResponder()

        let wasSelected = presetController!.presetIx == indexPath.row
        presetController!.selectPreset(preset: indexPath.row)
        
        tableView.reloadData()
        //tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        //tableView.reloadRows(at: [indexPath, IndexPath(row:oldIx,section:0)], with: UITableViewRowAnimation.automatic)
        //self.navigationController!.popViewController(animated: true)
        
        if (wasSelected){
            performSegue(withIdentifier: "PresetListToConfigView", sender: self)
        }
            
//        let p = presetController!.presets[indexPath.row]
//
//        if (p.factoryId >= 0)
//        {
//            return
//        }
        
//        let alert = UIAlertController(title: "Rename Preset", message: "Rename this preset", preferredStyle: .alert)
//
//        let saveAction = UIAlertAction(title: "Save", style: .default) {
//            [unowned self] action in
//
//            guard let textField = alert.textFields?.first,
//                let nameToSave = textField.text else {
//                    return
//            }
//
//            self.presetController!.presets[indexPath.row].name = nameToSave
//            self.presetController!.storePresets()
//            self.presetTable.reloadData()
//        }
//
//        let cancelAction = UIAlertAction(title: "Cancel", style: .default)
//
//        alert.addTextField()
//        alert.addAction(saveAction)
//        alert.addAction(cancelAction)
//
//        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        presetController!.swap(src: sourceIndexPath.row, dst: destinationIndexPath.row)
        
        reparentView(label:favs[0])
        
    }
}

extension PresetListViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return .none
    }
    
   func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
