//
//  MidiSettingsTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 3/16/20.
//

import UIKit

class MidiSettingsTableViewCell: UITableViewCell {

    let nameLabel = UILabel()
    let valueLabel = UILabel()
    let unitsLabel = UILabel()
    let stepCtrl = UIStepper()
    let switchCtrl = UISwitch()
    
    let stackView = UIStackView()
    
    var parentTable:UITableView? = nil

    var param:AUParameter? = nil
    {
        didSet {
            if (param?.unit == .boolean)
            {
                stepCtrl.isHidden = true
                valueLabel.isHidden = true
                switchCtrl.isOn = (param?.value ?? 0.0) > 0.0
            }
            else
            {
                switchCtrl.isHidden = true
                stepCtrl.value = Double(param?.value ?? 0.0)
            }
            nameLabel.text = param?.displayName
            
            stepCtrl.minimumValue = Double(param?.minValue ?? 0.0)
            stepCtrl.maximumValue = Double(param?.maxValue ?? 1.0)
            valueLabel.text = "\(Int(param?.value ?? 0.0))"
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        let viewsDict = [
            "name": nameLabel,
            "value": valueLabel,
            "units": unitsLabel,
            "stepper": stepCtrl,
            "switch": switchCtrl,
            "stack": stackView,
        ]
        
        for v in viewsDict.values {
            v.translatesAutoresizingMaskIntoConstraints = false
//            contentView.addSubview(v)
        }
        
        contentView.addSubview(stackView)
        stackView.alignment = .fill
        stackView.axis = .horizontal
        stackView.spacing = 8
        
        let spacerView = UIView()
        spacerView.isUserInteractionEnabled = false
        
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(spacerView)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(unitsLabel)
        stackView.addArrangedSubview(stepCtrl)
        stackView.addArrangedSubview(switchCtrl)
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[stack]-|", options: [], metrics: nil, views: viewsDict))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[stack]-|", options: [], metrics: nil, views: viewsDict))
        
        switchCtrl.onTintColor = .cyan

        stepCtrl.stepValue = 1
        stepCtrl.addTarget(self, action: #selector(self.stepperValueChanged(_:)), for: .valueChanged)
        switchCtrl.addTarget(self, action: #selector(self.switchValueChanged(_:)), for: .valueChanged)

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        
        // Configure the view for the selected state
    }
    
    @objc func stepperValueChanged(_ sender: UIStepper)
    {
        param?.value = AUValue(stepCtrl.value)
        valueLabel.text = "\(Int(param?.value ?? 0.0))"
        //parentTable?.reloadData()
    }
    @objc func switchValueChanged(_ sender: UIStepper)
    {
        print(switchCtrl.isOn)
        param?.value = AUValue(switchCtrl.isOn ? 1.0 : 0.0)
    }


}
