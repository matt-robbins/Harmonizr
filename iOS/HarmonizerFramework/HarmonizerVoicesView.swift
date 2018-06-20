//
//  HarmonizerVoicesView.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 3/19/18.
//

import UIKit

/*
 The `VoicesViewDelegate` protocol is used to notify a delegate (`HarmonizerViewController`)
 */

protocol VoicesViewDelegate: class {
    func voicesView(_ view: HarmonizerVoicesView, didChangeInversion inversion: Float)
    func voicesView(_ view: HarmonizerVoicesView, didChangeNvoices voices: Float)
}

@IBDesignable
class HarmonizerVoicesView: UIView {

    var borderWidth = 2
    var cornerRadius = 4
    var shadowRadius = 8
    
    weak var delegate: VoicesViewDelegate?
    
    var voices = 1
    var inversion = 0
    
    var autoTuneVoice1 = true {
        didSet {
            sync()
        }
    }
    
    func sync()
    {
        let sublayers = layer.sublayers!
        
        var sum = 0
        for k in 0...voices
        {
            sum += k
        }
        
        for k in 0...sublayers.count - 1
        {
            sublayers[k].borderWidth = 0
            
            if (k < sum && k >= (sum - voices))
            {
                
                if ((k - (sum - voices)) > inversion)
                {
                    sublayers[k].backgroundColor = UIColor.cyan.cgColor
                    sublayers[k].shadowOpacity = 1.0
                }
                else
                {
                    sublayers[k].backgroundColor = UIColor.yellow.cgColor
                    if (k - (sum - voices) == 0 && autoTuneVoice1)
                    {
                        sublayers[k].borderColor = UIColor.red.cgColor
                        sublayers[k].backgroundColor = UIColor.yellow.cgColor
                        sublayers[k].borderWidth = sublayers[k].frame.height/8
                    }
                    sublayers[k].shadowOpacity = 1.0
                }
            }
            else
            {
                sublayers[k].backgroundColor = UIColor.lightGray.cgColor
                sublayers[k].shadowOpacity = 0.0
            }
        }
    }
    
    func setSelectedVoices(_ voices: Int, inversion: Int)
    {
        self.voices = voices
        self.inversion = inversion
        
        sync()
    }
    
    override func awakeFromNib() {
        layer.contentsScale = UIScreen.main.scale
        layer.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
        layer.backgroundColor = UIColor.black.cgColor
        layer.borderWidth = CGFloat(borderWidth)
        layer.cornerRadius = CGFloat(cornerRadius)
        layer.shadowRadius = CGFloat(shadowRadius)
        layer.shadowColor = UIColor.cyan.cgColor
        layer.shadowOpacity = 0.0
        
        for _ in 0...9
        {
            let oval = CALayer()
            
            oval.backgroundColor = UIColor.darkGray.cgColor
            oval.borderWidth = 0
            oval.cornerRadius = 4
            
            oval.shadowColor = UIColor.cyan.cgColor
            oval.shadowOpacity = 0.0
            oval.shadowRadius = 5.0
            oval.shadowOffset = CGSize(width: 0, height: 0)
            
            layer.addSublayer(oval)
        }
    }
    
    override func layoutSublayers(of layer: CALayer) {
        let sublayers = layer.sublayers!
        let pipheight = layer.frame.height / 7
        var count = 0
        let pad: CGFloat = 5
        for nv in 0...3
        {
            for p in 0...nv
            {
                let xpos = pad + CGFloat(nv) * (layer.frame.width - pad) / 4
                let width: CGFloat = (layer.frame.width - 5 * pad) / 4
                let ypos = layer.frame.height * (1 - (CGFloat(p) + 0.5) / 4) - CGFloat(pipheight) / 2
                
                sublayers[count].frame = CGRect(x: xpos, y: ypos, width: width, height: CGFloat(pipheight))
                sublayers[count].cornerRadius = pipheight / 2
                sublayers[count].borderWidth = 0
                count += 1
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func processTouch(point: CGPoint) {
        var p = 1 + 4*((point.x) / self.layer.frame.width)
        var inv = 4*(1 - ((point.y) / self.layer.frame.height))
        if (inv > p - 1) { inv = p - 1 }
        if (inv < 0) { inv = 0 }
        if (p > 4) { p = 4 }
        if (p < 1) { p = 1 }
        //print(inv)
        delegate?.voicesView(self, didChangeNvoices: Float(p))
        delegate?.voicesView(self, didChangeInversion: Float(inv))
        self.setSelectedVoices(Int(p), inversion: Int(inv))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        processTouch(point: (touches.first?.location(in: self))!)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        processTouch(point: (touches.first?.location(in: self))!)
    }

}
