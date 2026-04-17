import Foundation
import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    func playBing() {
        // Try Asset Catalog first
        if let asset = NSDataAsset(name: "bingsound") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(data: asset.data)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                return
            } catch {
                print("SoundManager: Error playing from asset catalog: \(error)")
            }
        }
        
        // Fallback to Main Bundle (if added as a file)
        guard let url = Bundle.main.url(forResource: "bingsound", withExtension: "mp3") ?? 
                        Bundle.main.url(forResource: "bingsound", withExtension: "MP3") else {
            print("SoundManager: Could not find bingsound.mp3 in assets or bundle")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("SoundManager: Error playing from bundle: \(error)")
        }
    }
}
