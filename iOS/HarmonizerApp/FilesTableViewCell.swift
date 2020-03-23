//
//  FilesTableViewCell.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 3/23/20.
//

import UIKit
import AVFoundation
import AVKit

class FilesTableViewCell: UITableViewCell, AVAudioPlayerDelegate {

    let playButton = UIButton()
    let shareButton = UIButton()
    let nameLabel = UILabel()
    let stackView = UIStackView()
    var recordingURL:URL!
    var audioPlayer:AVAudioPlayer? = nil
    var parentController:UITableViewController? = nil
    
    var file:String = "" {
        didSet {
            nameLabel.text = file
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        let viewsDict = [
            "name": nameLabel,
            "stack": stackView,
            "play": playButton,
        ]
        
        for v in viewsDict.values {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        
        if #available(iOS 13.0, *) {
            playButton.setImage(UIImage(systemName: "play"), for: .normal)
        } else {
            playButton.setTitle("play", for: .normal)
        }
        if #available(iOS 13.0, *) {
            shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        } else {
            playButton.setTitle("share", for: .normal)
        }
        
        playButton.addTarget(self, action: #selector(self.play(_:)), for: .touchDown)
        shareButton.addTarget(self, action: #selector(self.share(_:)), for: .touchDown)
        
        contentView.addSubview(stackView)
        
        stackView.alignment = .fill
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.isUserInteractionEnabled = true
        
        //contentView.addSubview(playButton)
        let spacerView = UIView()
        spacerView.isUserInteractionEnabled = true
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(playButton)
        stackView.addArrangedSubview(spacerView)
        stackView.addArrangedSubview(shareButton)
        
        contentView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-[stack]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
        contentView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-[stack]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)
        print("selected")
        // Configure the view for the selected state
    }
    
    @objc func play(_ sender: UIButton) {
        if (audioPlayer?.isPlaying ?? false)
        {
            audioPlayer?.stop()
            audioPlayerDidFinishPlaying(audioPlayer!, successfully: true)
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL.appendingPathComponent(file))
            audioPlayer?.delegate = self
        }
        catch {
            print(error.localizedDescription)
        }
        audioPlayer?.play()
        if #available(iOS 13.0, *) {
            playButton.setImage(UIImage(systemName: "pause"), for: .normal)
        } else {
            playButton.setTitle("pause", for: .normal)
        }
        
    }
    @objc func share(_ sender: UIButton) {
        print("presenting")
        let activityVC = UIActivityViewController(activityItems: [recordingURL.appendingPathComponent(file)],applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self
  
        parentController?.present(activityVC, animated: true, completion: nil)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool)
    {
        print("finished!")
        if #available(iOS 13.0, *) {
            playButton.setImage(UIImage(systemName: "play"), for: .normal)
        } else {
            playButton.setTitle("play", for: .normal)
        }
    }

}
