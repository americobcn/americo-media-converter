//
//  MediaController.swift
//  MyApp
//
//  Created by Américo Cot Toloza on 23/3/25.
//

import Foundation
import AVFoundation


class MediaController: NSObject {
    var urlAsset: AVURLAsset!
    var videoFormatDesc: CMFormatDescription!
    var audioFormatDesc: CMFormatDescription!
    
    func isAVMediaType(url: URL) -> (isPlayable: Bool, formats: [String: Any]) {
        var format: [String:Any] = [:]
        let urlAsset = AVURLAsset(url: url)
        if urlAsset.isPlayable {
            format = getMetadata(asset: urlAsset)
            return (isPlayable: true, formats: format)
        }
        
        return (isPlayable: true, formats: format)
    }
    
    func getMetadata(asset: AVURLAsset ) -> [String: Any] {
        var videoFormatDesc: CMVideoFormatDescription?
        var audioFormatDesc: CMAudioFormatDescription?
        var formats: [String:Any] = [:]
        
        for track in asset.tracks {
            switch track.mediaType {
            case .video:
                videoFormatDesc = ((track.formatDescriptions[0] ) as! CMVideoFormatDescription)
                formats["videoDesc"] = videoFormatDesc
                formats["rate"] = track.nominalFrameRate
                formats["icon"] = "video"
                break
            case .audio:
                audioFormatDesc = ((track.formatDescriptions[0] ) as! CMAudioFormatDescription)
                formats["audioDesc"] = audioFormatDesc
                formats["icon"] = "hifispeaker"
                break
            default:
                break
            }
        }
        return  formats
    }

}
