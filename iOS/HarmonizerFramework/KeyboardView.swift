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

class Key: CATextLayer {
    
    var midinote: Int = 0 {
        didSet {
            if (midinote % 12 == 0)
            {
                self.string = "C\((midinote / 12) - 1)"
            }
        }
    }
    
    var labelVisible: Bool = true {
        didSet {
            self.foregroundColor = labelVisible ?  UIColor.lightText.cgColor : UIColor.clear.cgColor
        }
    }
    
    var black: Bool = false
    {
        didSet {
            self.backgroundColor = black ? UIColor.black.cgColor : UIColor.white.cgColor
        }
    }
    
    var tintColor = UIColor.orange.cgColor {
        didSet {
            shadowColor = tintColor
        }
    }
    
    func configure() {
        contentsScale = UIScreen.main.scale
        backgroundColor = UIColor.white.cgColor
        foregroundColor = UIColor.darkGray.cgColor
        shadowColor = tintColor
        cornerRadius = 2
        borderWidth = 2
        borderColor = UIColor.darkGray.cgColor
        shadowOffset = CGSize(width: 0, height: 0)
        shadowRadius = 8
        masksToBounds = false
        alignmentMode = kCAAlignmentCenter
        fontSize = 14
        contentsScale = UIScreen.main.scale
    }
    
    override func draw(in ctx: CGContext) {
        let height = self.bounds.size.height
        let fontSize = self.fontSize
        let yDiff = height - 2*fontSize
        
        ctx.saveGState()
        ctx.translateBy(x: 0.0, y: yDiff)
        super.draw(in: ctx)
        ctx.restoreGState()
    }
    
    override init(layer: Any)
    {
        self.isSelected = false
        self.isSung = false
        self.isHarm = false
        super.init(layer: layer)
    }
    
    override init() {
        midinote = 0
        self.isSelected = false
        self.isSung = false
        self.isHarm = false
        super.init()
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.isSelected = false
        self.isSung = false
        self.isHarm = false
        super.init(coder: aDecoder)
        
        // set other operations after super.init if required
        self.configure()
    }
    
    func toggleActive(_ flag: Bool, color: CGColor)
    {
        CATransaction.begin()
        if ( flag ) {
            CATransaction.setAnimationDuration(0.05)
            self.backgroundColor = color
            self.shadowColor = color
            self.shadowOpacity = 1.0
        }
        else {
            CATransaction.setAnimationDuration(0.2)
            self.backgroundColor = self.black ? UIColor.black.cgColor : UIColor.white.cgColor
            self.shadowOpacity = 0.0
        }
        CATransaction.commit()
    }
    
    var isSelected: Bool {
        didSet {
            toggleActive(isSelected, color: tintColor)
        }
    }
    
    var isSung: Bool {
        didSet {
            if (!isSelected)
            {
                toggleActive(isSung, color: tintColor)
                //borderColor = isSung ? UIColor.red.cgColor : UIColor.darkGray.cgColor
            }
        }
    }
    
    var isHarm: Bool {
        didSet {
            if (!isSelected)
            {
                toggleActive(isHarm, color: UIColor.yellow.cgColor)
                //borderColor = isSung ? UIColor.red.cgColor : UIColor.darkGray.cgColor
            }
        }
    }
}

class Marker: CALayer {
    override func contains(_ p: CGPoint) -> Bool {
        return false
    }
}

@IBDesignable
class KeyboardView: UIView {
    
    let nkeys = 128
    @IBInspectable var n_visible: Int = 14
    {
        didSet {
            layoutSublayers(of: self.layer)
        }
    }
    var wkeys = [Key]()
    var bkeys = [Key]()
    var keys = [Key]()
    var markers = [Marker]()
    
    var markKey = 1
    {
        didSet {
            
        }
    }
    
    var labels: Bool = true {
        didSet {
            for key in keys {
                key.labelVisible = labels
            }
        }
    }

    var spacing: CGFloat = 20
    var playable: Bool = true
    
    var start_pos = CGPoint.zero
    
    var points = [CGPoint]()
    
    var keyOffset = 0 {
        didSet {
            if (keyOffset < 0)
            {
                keyOffset = 0
            }
            if (keyOffset > 70 - n_visible)
            {
                keyOffset = 70 - n_visible
            }
            var newPos = CGPoint.zero
            newPos.x -= CGFloat(keyOffset) * spacing
            containerLayer.position = newPos
        }
    }
    
    var containerLayer: CALayer = CALayer()
    weak var delegate: KeyboardViewDelegate?
    
    override func awakeFromNib() {
        
        containerLayer.name = "container"
        containerLayer.anchorPoint = CGPoint.zero
        containerLayer.frame = CGRect(origin: CGPoint.zero, size: layer.bounds.size)
        layer.masksToBounds = true
        layer.addSublayer(containerLayer)
        
        for i in 0...nkeys-1
        {
            let keyLayer = Key()
            keyLayer.black = [1,3,6,8,10].contains(i%12)
            keyLayer.tintColor = tintColor.cgColor
            keyLayer.midinote = i
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
            containerLayer.addSublayer(keyLayer)
        }
        
        for ix in 0...4
        {
            let marker = Marker()
            markers.append(marker)
            marker.zPosition = ix == 0 ? 2.0 : 1.5
            containerLayer.addSublayer(marker)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSublayers(of layer: CALayer) {
        layer.backgroundColor = UIColor.black.cgColor
        
        containerLayer.bounds = layer.bounds
        
        spacing = layer.frame.width / CGFloat(n_visible)
        
        keyOffset = 28
        
        if (wkeys.count < 1 || bkeys.count < 1) { return }
        
        for i in 0...wkeys.count-1
        {
            wkeys[i].frame = CGRect(x: CGFloat(i) * spacing, y: 0, width: spacing, height: layer.frame.height)
        }
        
        for i in 0...bkeys.count-1
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
        
        var ix = 0
        for marker in markers {
            marker.frame = CGRect(x: (CGFloat(0) + 0.5) * spacing - spacing/8, y: 5, width: spacing/4, height: spacing/4)
            
            let color = ix == 0 ? UIColor.red.cgColor : UIColor.yellow.cgColor
            
            marker.backgroundColor = color
            marker.cornerRadius = marker.frame.width/2
            marker.shadowRadius = 5
            marker.shadowColor = color
            marker.shadowOpacity = 1.0
            marker.opacity = 0.6
            ix += 1
        }
        
    }
    
    override func tintColorDidChange() {
        for key in keys {
            key.tintColor = self.tintColor.cgColor
        }
        
//        for marker in markesr {
//            marker.backgroundColor = self.tintColor.cgColor
//            marker.shadowColor = self.tintColor.cgColor
//        }
    }
    
    func avg_pos(_ points: Set<UITouch>) -> CGPoint
    {
        var avgx: CGFloat = 0.0
        var avgy: CGFloat = 0.0
        
        if (points.count > 0)
        {
            for p in points {
                avgx += p.location(in:self).x
                avgy += p.location(in:self).y
            }
            
            avgx /= CGFloat(points.count)
            avgy /= CGFloat(points.count)
        }
        return CGPoint(x: avgx, y: avgy)
    }
    
    @discardableResult
    func calculate_movement(_ touches: Set<UITouch>, _ editing: Bool) -> Bool
    {
        let cur_pos = avg_pos(touches)
        var done = false
        if (cur_pos.y < 0 && start_pos == CGPoint.zero && touches.count == 1)
        {
            containerLayer.position.y = -20
            start_pos = cur_pos
        }
        
        let hdiff = cur_pos.x - start_pos.x
        
        if (start_pos != CGPoint.zero)
        {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            containerLayer.position.x = -CGFloat(keyOffset) * spacing + hdiff
            CATransaction.commit()
            
            if (cur_pos.y > 0 || !editing)
            {
                start_pos = CGPoint.zero
                containerLayer.position.y = 0
                let off = (containerLayer.position.x + CGFloat(keyOffset) * spacing) / spacing
                keyOffset -= Int(round(off))
                done = true
            }
        }
        
        return done
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches
        {
            let p = t.location(in:self)
            
            if (playable)
            {
                let key = containerLayer.hitTest(p) as? Key
                if (key != nil)
                {
                    key!.isSelected = true
                    delegate?.keyboardView(self, noteOn: key!.midinote)
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if (calculate_movement((event?.allTouches)!, true))
        {
            allNotesOff()
        }
        if (start_pos != CGPoint.zero)
        {
            return
        }
        
        for t in touches
        {
            let p = t.location(in: self)
            let op = t.previousLocation(in: self)
            
            let key = containerLayer.hitTest(p) as? Key
            let old_key = containerLayer.hitTest(op) as? Key

            if (key != nil)
            {
                key!.isSelected = true
                
                if (old_key != nil && key != old_key)
                {
                    old_key!.isSelected = false
                    delegate?.keyboardView(self, noteOn: key!.midinote)
                    delegate?.keyboardView(self, noteOff: old_key!.midinote)
                }
            }
            else
            {
                if (old_key != nil)
                {
                    old_key!.isSelected = false
                    delegate?.keyboardView(self, noteOff: old_key!.midinote)
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        if (calculate_movement((event?.allTouches)!, false))
        {
            allNotesOff()
        }
        
        for t in touches
        {
            let op = t.previousLocation(in: self)
            
            let key = containerLayer.hitTest(op) as? Key
            
            if (key != nil)
            {
                key!.isSelected = false
                delegate?.keyboardView(self, noteOff: key!.midinote)
            }
        }
    }
    
    func allNotesOff()
    {
        for k in keys {
            k.isSelected = false
            delegate?.keyboardView(self, noteOff: k.midinote)
        }
    }
    
    func setCurrentNote(_ notes: [Int])
    {
        for ix in 0...markers.count-1
        {
            markKey = notes[ix]
            
            let marker = markers[ix]
            
            if (markKey < 1 || markKey > keys.count - 1) {
                marker.opacity = 0.0
                continue
            }
            
            marker.opacity = 0.8
            var center: CGFloat = 0
            if (keys[markKey].black)
            {
                center = (keys[markKey].frame.maxX + keys[markKey].frame.minX)/2
            }
            else {
                center = (keys[markKey+1].frame.minX + keys[markKey-1].frame.maxX)/2
            }
            marker.frame = CGRect(x: center - spacing/8, y: 2, width: spacing/4, height: spacing/4)
            marker.cornerRadius = spacing/8
        }
    }
    
    func keyShift(_ inc: Int)
    {
        allNotesOff()
        keyOffset += inc
    }
}
