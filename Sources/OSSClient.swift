//
//  OSSClient.swift
//  AliyunOSSMac
//
//  Created by HanXu on 27/12/2016.
//
//

import Cocoa
import Foundation
import CryptoSwift

public enum OSSClientError: Error {
    case invalidImage
    case signFailure
    case uploadFailure
}

public class OSSClient {
    public enum Area {
        case hangZhou
        
        func url(for object: String, in bucket: String) -> URL {
            switch self {
            case .hangZhou:
                return URL(string: "https://\(bucket).oss-cn-hangzhou.aliyuncs.com/\(object)")!
            }
        }
    }
    
    private let accessId: String
    private let accessSecret: String
    private let area: Area
    
    public init(accessId: String, accessSecret: String, area: Area) {
        self.accessId = accessId
        self.accessSecret = accessSecret
        self.area = area
    }
    
    public func uploadImage(image: NSImage, name: String, to bucket: String, onSuccess: ((URL) -> ())?, onFailure: ((OSSClientError) -> ())?) {
        guard let imageRef = image.representations.first as? NSBitmapImageRep else {
            onFailure?(OSSClientError.invalidImage)
            return
        }
        guard let data = imageRef.representation(using: .JPEG, properties: [:]) else {
            onFailure?(OSSClientError.invalidImage)
            return
        }
        
        let md5 = data.md5()
        let md5String = md5.base64EncodedString()
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let timeString = dateFormatter.string(from: Date())
        
        let contentType = "image/jpg"
        let object = name.hasSuffix(".jpg") ? name : name + ".jpg"
        let ossResource = "/\(bucket)/\(object)"
        
        guard let signature = self.calcSignature(verb: "PUT", contentMD5: md5String, contentType: contentType, timeString: timeString, ossResource: ossResource) else {
            onFailure?(OSSClientError.signFailure)
            return
        }
        
        let authorization = "OSS \(self.accessId):\(signature)"
        
        let url = self.area.url(for: object, in: bucket)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.addValue(md5String, forHTTPHeaderField: "Content-MD5")
        request.addValue(timeString, forHTTPHeaderField: "Date")
        request.addValue(authorization, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            let resp = response as! HTTPURLResponse
            if resp.statusCode == 200 {
                onSuccess?(url)
            } else {
                onFailure?(OSSClientError.uploadFailure)
            }
        }
        task.resume()
    }

    private func calcSignature(verb: String, contentMD5: String, contentType: String, timeString: String, ossResource: String, ossHeaders: [String:String] = [:]) -> String? {
        var signingString = "\(verb.uppercased())\n\(contentMD5)\n\(contentType)\n\(timeString)\n"
        
        let sortedKeys = ossHeaders.keys.sorted()
        for key in sortedKeys {
            signingString += "\(key.lowercased()):\(ossHeaders[key]!)\n"
        }
        
        signingString += "\(ossResource)"
        
        let bytes = signingString.utf8.map {$0}
        guard let signed = try? HMAC(key: self.accessSecret, variant: .sha1).authenticate(bytes) else {
            return nil
        }

        return signed.toBase64()
    }
}
