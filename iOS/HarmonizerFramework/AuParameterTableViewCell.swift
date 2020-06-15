//
//  MidiSettingsTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 3/16/20.
//

import UIKit

class AuParameterTableViewCell: UITableViewCell {

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
                switchCtrl.isHidden = false
                switchCtrl.isOn = (param?.value ?? 0.0) > 0.0
            }
            else
            {
                switchCtrl.isHidden = true
                valueLabel.isHidden = false
                stepCtrl.isHidden = false
                stepCtrl.value = Double(param?.value ?? 0.0)
            }
            nameLabel.text = (param?.displayName ?? param?.identifier)?.capitalized
            
            stepCtrl.minimumValue = Double(param?.minValue ?? 0.0)
            stepCtrl.maximumValue = Double(param?.maxValue ?? 1.0)
            
            switch (param?.unit)
            {
            case .indexed,.midiController:
                stepCtrl.stepValue = 1.0
            default:
                stepCtrl.stepValue = round((stepCtrl.maximumValue - stepCtrl.minimumValue) * 100) / 10000
            }
            setValueLabel()
            //valueLabel.text = "\(Int(param?.value ?? 0.0))"
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
        
        //self.backgroundColor = UIColor.black

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        
        // Configure the view for the selected state
    }
    
    func setValueLabel()
    {
        switch (param!.unit) {
        case .percent:
            valueLabel.text = "\(Int(param?.value ?? 0.0))"
            unitsLabel.text = "%"
        case .indexed,.midiController:
            valueLabel.text = "\(Int(param?.value ?? 0.0))"
        case .decibels:
            valueLabel.text = "\(param?.value ?? 0.0)"
            unitsLabel.text = "dB"
        case .seconds:
            valueLabel.text = "\(param?.value ?? 0.0)"
            unitsLabel.text = "S"
        case .generic:
            valueLabel.text = "\(param?.value ?? 0.0)"
        default:
            valueLabel.text = "\(Int(param?.value ?? 0.0))"
            unitsLabel.text = ""
        }
    }
    
    @objc func stepperValueChanged(_ sender: UIStepper)
    {
        param?.value = AUValue(stepCtrl.value)
        setValueLabel()
        //parentTable?.reloadData()
    }
    @objc func switchValueChanged(_ sender: UIStepper)
    {
        print(switchCtrl.isOn)
        param?.value = AUValue(switchCtrl.isOn ? 1.0 : 0.0)
    }


}
