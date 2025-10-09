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
        
        return (isPlayable: false, formats: format)
    }
    
    func getMetadata(asset: AVURLAsset ) -> [String: Any] {
        var videoFormatDesc: CMVideoFormatDescription?
        var audioFormatDesc: CMAudioFormatDescription?
        var timeFromatDesc: CMTimeCodeFormatDescription?
        
        var formats: [String:Any] = [:]
        // print("ASSET DESCRIPTION: \(mediaAssetDescription(asset: asset, mediaType: kCMMediaType_Video))")
        for track in asset.tracks {
            // print("DESCRIPTORS: \(track.formatDescriptions)")
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
            case .timecode:
                timeFromatDesc = ((track.formatDescriptions[0]) as! CMTimeCodeFormatDescription)
                formats["tcDesc"] = timeFromatDesc
            default:
                break
            }
        }
        // print("TC Frame Rate: \(timeFromatDesc?.frameQuanta ?? 0)")
        return  formats
    }
    
    
    func mediaAssetDescription(asset: AVURLAsset, mediaType: CMMediaType) -> [Any] {
        let formatDescriptions = asset.tracks.flatMap { $0.formatDescriptions }
        // let mediaSubtypes = formatDescriptions
        //     .filter { CMFormatDescriptionGetMediaType($0 as! CMFormatDescription) == mediaType }
        //     .map { CMFormatDescriptionGetMediaSubType($0 as! CMFormatDescription).toString() }
        return formatDescriptions.filter { CMFormatDescriptionGetMediaType($0 as! CMFormatDescription) == mediaType }
    }
}
