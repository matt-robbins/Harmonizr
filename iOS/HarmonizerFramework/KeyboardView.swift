//
//  KeyboardView.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 5/21/18.
//

import UIKit

/*
 The `HarmonizerViewDelegate` protocol is used to notify a delegate (`HarmonizerViewController`)
 */
protocol KeyboardViewDelegate: class {
    func keyboardView(_ view: KeyboardView, noteOn note: Int)
    func keyboardView(_ view: KeyboardView, noteOff note: Int)
}

class Key: CALayer {
    
    var midinote: Int = 0
    var black: Bool = false
    {
        didSet {
            self.backgroundColor = black ? UIColor.black.cgColor : UIColor.white.cgColor
        }
    }
    
    func configure() {
        contentsScale = UIScreen.main.scale
        backgroundColor = UIColor.white.cgColor
        shadowColor = UIColor.cyan.cgColor
        cornerRadius = 2
        borderWidth = 2
        borderColor = UIColor.darkGray.cgColor
        shadowOffset = CGSize(width: 0, height: 0)
        shadowRadius = 8
        masksToBounds = false
    }
    
    override init(layer: Any)
    {
        self.isSelected = false
        self.isSung = false
        super.init(layer: layer)
    }
    
    override init() {
        midinote = 0
        self.isSelected = false
        self.isSung = false
        super.init()
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.isSelected = false
        self.isSung = false
        super.init(coder: aDecoder)
        
        // set other operations after super.init if required
        self.configure()
    }
    
    func toggleActive(_ flag: Bool, color: CGColor)
    {
        if ( flag ) {
            self.backgroundColor = color
            self.shadowColor = color
            self.shadowOpacity = 1.0
        }
        else {
            self.backgroundColor = self.black ? UIColor.black.cgColor : UIColor.white.cgColor
            self.shadowOpacity = 0.0
        }
    }
    
    var isSelected: Bool {
        didSet {
            toggleActive(isSelected, color: UIColor.cyan.cgColor)
        }
    }
    
    var isSung: Bool {
        didSet {
            if (!isSelected)
            {
                toggleActive(isSung, color: UIColor.cyan.cgColor)
                borderColor = isSung ? UIColor.red.cgColor : UIColor.darkGray.cgColor
            }
        }
    }
}

class KeyboardView: UIView {
    
    let nkeys = 24
    let nwkeys = 14
    let nbkeys = 10
    var wkeys = [Key]()
    var bkeys = [Key]()
    var keys = [Key]()
    
    var midiOctave = 4
    var touchesDown = 0
    
    weak var delegate: KeyboardViewDelegate?
    
    override func awakeFromNib() {
        
        for i in 0...nkeys-1
        {
            let keyLayer = Key()
            keyLayer.black = [1,3,6,8,10].contains(i%12)
            keyLayer.midinote = midiOctave * 12 + i
            keys.append(keyLayer)
            if (keyLayer.black)
            {
                bkeys.append(keyLayer)
                keyLayer.zPosition = 1.0
            }
            else {
                wkeys.append(keyLayer)
                keyLayer.zPosition = 0.0
            }
            layer.addSublayer(keyLayer)
        }
    }

    override func layoutSublayers(of layer: CALayer) {
        layer.backgroundColor = UIColor.black.cgColor
        
        let spacing = layer.frame.width / CGFloat(nwkeys)
        
        for i in 0...nwkeys-1
        {
            wkeys[i].frame = CGRect(x: CGFloat(i) * spacing, y: 0, width: spacing, height: layer.frame.height)
        }
        
        for i in 0...nbkeys-1
        {
            let oct = Int(i / 5)
            let k = i % 5
            var s = 0
            if (k > 1) { s = 1 }

            let bkwidth = spacing*3/5
            var offset = bkwidth/2
            switch (k)
            {
            case 0,2:
                offset += bkwidth/8
            case 4,1:
                offset -= bkwidth/8
            default:
                offset += 0
            }
            bkeys[i].frame = CGRect(x: CGFloat(1 + k + s + 7 * oct) * spacing - offset, y: 0, width: bkwidth, height: layer.frame.height*3/5)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches
        {
            touchesDown = touchesDown + 1
            let p = layer.convert(t.location(in: self), to: layer.superlayer!)
            let k = self.layer.hitTest(p) as? Key
            if (k != nil)
            {
                k!.isSelected = true
                delegate?.keyboardView(self, noteOn: k!.midinote)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        for t in touches
        {
            let p = layer.convert(t.location(in: self), to: layer.superlayer!)
            let p2 = layer.convert(t.previousLocation(in: self), to: layer.superlayer!)

            let k = layer.hitTest(p) as? Key
            let ok = layer.hitTest(p2) as? Key

            if (k != nil)
            {
                k!.isSelected = true
                if (ok != nil && ok != k)
                {
                    ok!.isSelected = false
                    delegate?.keyboardView(self, noteOn: k!.midinote)
                    delegate?.keyboardView(self, noteOff: ok!.midinote)
                }
            }
            else
            {
                if (ok != nil)
                {
                    ok!.isSelected = false
                    delegate?.keyboardView(self, noteOff: ok!.midinote)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with Event: UIEvent?)
    {
        for t in touches
        {
            touchesDown = touchesDown - 1
            let p = layer.convert(t.location(in: self), to: layer.superlayer!)
            let k = layer.hitTest(p) as? Key
            if (k != nil)
            {
                k!.isSelected = false
                delegate?.keyboardView(self, noteOff: k!.midinote)
            }
            if (touchesDown == 0)
            {
                for k in keys
                {
                    k.isSelected = false
                    delegate?.keyboardView(self,noteOff: k.midinote)
                }
            }
        }
    }
    
    func setCurrentNote(_ note: Float)
    {
        let n = Int(round(note))
        for k in keys
        {
            k.isSung = (k.midinote == n)
        }
    }
}
