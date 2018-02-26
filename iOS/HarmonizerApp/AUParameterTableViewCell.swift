//
//  AUParameterTableViewCell.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 2/23/18.
//

import UIKit

class AUParameterTableViewCell: UITableViewCell {

    @IBOutlet weak var valueSlider: UISlider!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
