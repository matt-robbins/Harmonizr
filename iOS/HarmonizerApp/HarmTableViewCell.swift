//
//  HarmTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 6/18/18.
//

import UIKit

class HarmTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        let v = UIView()
        v.backgroundColor = tintColor
        selectedBackgroundView = v
        
        // Configure the view for the selected state
    }

}
