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
    let sliderCtrl = UISlider()
    let btnCtrl = UIButton()
    
    let stackView = UIStackView()
    
    var parentTable:UITableView? = nil

    var param:AUParameter? = nil
    {
        didSet {
            stepCtrl.isHidden = true
            sliderCtrl.isHidden = true
            valueLabel.isHidden = true
            switchCtrl.isHidden = true
            btnCtrl.isHidden = true
            
            nameLabel.text = (param?.displayName ?? param?.identifier)?.capitalized
            
            stepCtrl.minimumValue = Double(param?.minValue ?? 0.0)
            sliderCtrl.minimumValue = param?.minValue ?? 0.0
            
            stepCtrl.maximumValue = Double(param?.maxValue ?? 1.0)
            sliderCtrl.maximumValue = param?.maxValue ?? 1.0
            
            stepCtrl.value = Double(param?.value ?? 0.0)
            sliderCtrl.value = param?.value ?? 0.0
            
            switch (param?.unit)
            {
            case .boolean:
                switchCtrl.isHidden = false
                switchCtrl.isOn = (param?.value ?? 0.0) > 0.0
            case .linearGain:
                sliderCtrl.isHidden = false
            case .decibels,.percent:
                stepCtrl.isHidden = false
                valueLabel.isHidden = false
            case .generic:
                sliderCtrl.isHidden = false
                stepCtrl.stepValue = 0.01;
            case .indexed,.midiController:
                valueLabel.isHidden = false
                stepCtrl.isHidden = false
            default:
                stepCtrl.isHidden = false
                valueLabel.isHidden = false
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
            "slider": sliderCtrl,
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
        
        sliderCtrl.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true
        let spacerView = UIView()
        spacerView.isUserInteractionEnabled = false
        
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(spacerView)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(unitsLabel)
        stackView.addArrangedSubview(stepCtrl)
        stackView.addArrangedSubview(switchCtrl)
        stackView.addArrangedSubview(sliderCtrl)
        stackView.addArrangedSubview(btnCtrl)
        
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[stack]-|", options: [], metrics: nil, views: viewsDict))
        contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[stack]-|", options: [], metrics: nil, views: viewsDict))
        
        switchCtrl.onTintColor = .cyan

        stepCtrl.stepValue = 1
        
        stepCtrl.addTarget(self, action: #selector(self.stepperValueChanged(_:)), for: .valueChanged)
        switchCtrl.addTarget(self, action: #selector(self.switchValueChanged(_:)), for: .valueChanged)
        sliderCtrl.addTarget(self, action: #selector(self.sliderValueChanged(_:)), for: .valueChanged)
        
        //self.backgroundColor = UIColor.black

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        
        // Configure the view for the selected state
    }
    
    func setValueLabel()
    {
        let val = param?.value ?? 0.0
        let val_2 = Double(Int(val*100))/100.0
        switch (param!.unit) {
        case .percent:
            valueLabel.text = "\(Int(val))"
            unitsLabel.text = "%"
        case .midiController:
            valueLabel.text = "\(Int(val))"
        case .decibels:
            valueLabel.text = "\(val_2)"
            unitsLabel.text = "dB"
        case .seconds:
            valueLabel.text = "\(val_2)"
            unitsLabel.text = "S"
        case .generic:
            valueLabel.text = "\(val_2)"
        case .indexed:
            if let st = param?.valueStrings! {
                valueLabel.text = "\(st[Int(val)])"
            }
            else {
                valueLabel.text = "\(Int(val))"
            }
        default:
            valueLabel.text = ""
            unitsLabel.text = ""
        }
    }
    
    @objc func stepperValueChanged(_ sender: UIStepper)
    {
        param?.value = AUValue(stepCtrl.value)
        setValueLabel()
        //parentTable?.reloadData()
    }
    
    @objc func sliderValueChanged(_ sender: UISlider)
    {
        param?.value = AUValue(sliderCtrl.value)
        setValueLabel()
        //parentTable?.reloadData()
    }
    @objc func switchValueChanged(_ sender: UIStepper)
    {
        print(switchCtrl.isOn)
        param?.value = AUValue(switchCtrl.isOn ? 1.0 : 0.0)
    }


}
