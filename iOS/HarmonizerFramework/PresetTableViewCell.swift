//
//  PresetTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 3/9/21.
//

import UIKit

class PresetTableViewCell: UITableViewCell {
    @IBOutlet weak var name: UITextField!
    @IBOutlet weak var led: Led!
    @IBOutlet weak var fav: UIView!
    
    override func awakeFromNib() {
        //fav.setTitleColor(.black, for: .normal)
        //led.tintColor = .cyan
        
        name.enablesReturnKeyAutomatically = true
    }
    
    func selectMe() {
        name.selectAll(nil)
        name.becomeFirstResponder()
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)

//        self.led.power(on: selected)
//        self.accessoryType = selected ? .disclosureIndicator : .none
//        self.accessoryView?.tintColor = tintColor
    }
}
