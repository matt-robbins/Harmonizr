//
//  LinkTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 4/14/26.
//

import UIKit

class LinkTableViewCell: UITableViewCell {

    let nameLabel = UILabel()
    var parentTable:UITableView? = nil

    var name:String? = nil
    {
        didSet {
            nameLabel.text = name
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        nameLabel.text = name
        contentView.addSubview(nameLabel)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        
        // Configure the view for the selected state
    }
}
