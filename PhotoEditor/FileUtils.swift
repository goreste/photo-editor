//
//  FileUtils.swift
//  editorTest
//
//  Created by Paolo Furlan on 06/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import UIKit

//MARK: - Utils

extension FileManager {
    func scanDirectory(directory: SearchPathDirectory, for fileExtension: String) -> [URL] {
        guard let dirPath = try? url(for: directory, in: .userDomainMask, appropriateFor: nil, create: false) else { return [] }
        guard let fileEnumerator = enumerator(at: dirPath, includingPropertiesForKeys: nil, options: DirectoryEnumerationOptions()) else { return [] }
        var files: [URL] = []
        while let url = fileEnumerator.nextObject() {
            guard let url = url as? URL else { continue }
            files.append(url)
        }
        return files.filter { $0.pathExtension == fileExtension }
    }
    
    func documentsUrl() -> URL? {
        return try? url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    
    func cachesUrl() -> URL? {
        return try? url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    
    func scanDocumentsFor(fileExtension: String) -> [URL] {
        return scanDirectory(directory: .documentDirectory, for: fileExtension)
    }
    
    func scanBundleFor(fileExtension: String) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == fileExtension }
    }
    
    func saveImageToDocuments(image: UIImage, fileExtension: String = "png") {
        guard let imageData = UIImagePNGRepresentation(image) else { return }
        guard let documentsUrl = documentsUrl() else { return }
        let path = documentsUrl.appendingPathComponent("\(Date().timeIntervalSince1970).\(fileExtension)").path
        print("image created: \(path)")
        FileManager.default.createFile(atPath: path, contents: imageData, attributes: nil)
    }
}


struct FileUtils {
    static func scanGifFiles() -> [URL] {
        return scanFilesFor(fileExtension: "gif")
    }
    
    static func scanFilesFor(fileExtension: String) -> [URL] {
        let filesInBundle = scanBundleFor(fileExtension: fileExtension)
        let filesInDocuments = scanDocumentsFor(fileExtension: fileExtension)
        let filesInCaches = scanCachesFor(fileExtension: fileExtension)
        return filesInDocuments + filesInCaches + filesInBundle
    }
    
    static func scanBundleFor(fileExtension: String) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == fileExtension }
    }
    
    static func scanDocumentsFor(fileExtension: String) -> [URL] {
        return FileManager.default.scanDirectory(directory: .documentDirectory, for: fileExtension)
    }
    
    static func scanCachesFor(fileExtension: String) -> [URL] {
        return FileManager.default.scanDirectory(directory: .cachesDirectory, for: fileExtension)
    }
}
