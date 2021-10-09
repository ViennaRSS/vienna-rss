//
//  WebKitArticleConverter.swift
//  Vienna
//
//  Copyright 2020 Tassilo Karge
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import CommonCrypto
import Foundation
import WebKit

class WebKitArticleConverter: ArticleConverter {

    override func initForStyle(at path: URL) {
        copyStyleContent(from: path)
        emptyLocalDataCache()
    }

    private func getCachesPath() -> URL {
        let directory = FileManager.default.cachesDirectory.appendingPathComponent("article")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Could not create cache directory for displaying article (\(error))")
        }
        return directory
    }

    func copyStyleContent(from path: URL) {

        guard let files = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            fatalError("Was not able to list files of style")
        }

        let targetDirectory = getCachesPath()

        do {
            for url in try FileManager.default.contentsOfDirectory(at: targetDirectory, includingPropertiesForKeys: nil) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            fatalError("Could not clear directory \(targetDirectory) because \(error)")
        }

        for url in files {
            do {
                try FileManager.default.copyItem(at: url, to: targetDirectory.appendingPathComponent(url.lastPathComponent))
            } catch {
                fatalError("copy \(url) failed because \(error)")
            }
        }

        let templateUrl = targetDirectory.appendingPathComponent("template.html")
        if FileManager.default.fileExists(atPath: templateUrl.path) {
            self.htmlTemplate = (try? String(contentsOf: templateUrl)) ?? ""
        }
        let cssUrl = targetDirectory.appendingPathComponent("stylesheet.css")
        self.cssStylesheet = FileManager.default.fileExists(atPath: cssUrl.path) ? cssUrl.absoluteString : ""
        let jsUrl = targetDirectory.appendingPathComponent("script.js")
        self.jsScript = FileManager.default.fileExists(atPath: jsUrl.path) ? jsUrl.absoluteString : ""
    }

    private func emptyLocalDataCache() {
        // WKWebsiteDataRecord does not give us an identifier.
        // However, the only name with spaces in it is that for local files
        // all the other names are the hostname of the corresponding website
        let isLocalWebsiteData = { (record: WKWebsiteDataRecord) in record.displayName.contains(" ") }

        let types: Set<String> = [WKWebsiteDataTypeMemoryCache]

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            for record in records {
                if isLocalWebsiteData(record) {
                    WKWebsiteDataStore.default().removeData(ofTypes: types, for: [record]) {}
                }
            }
        }
    }

    func prepareArticleDisplay(_ articles: [Article]) -> (URL) {

        guard !articles.isEmpty else {
            fatalError("an empty articles array cannot be presented")
        }

        let articleHtml: String = self.articleText(from: articles)

        // Give an article or specific array of articles always the same name
        let uuidFileName = uniqueId(for: articleHtml).appending(".html")

        let articleDirectory = getCachesPath()
        let htmlPath = articleDirectory.appendingPathComponent(uuidFileName)

        do {
            if FileManager.default.fileExists(atPath: htmlPath.path) {
                try FileManager.default.removeItem(at: htmlPath)
            }
            try articleHtml.write(to: htmlPath, atomically: true, encoding: .utf8)
        } catch {
            fatalError("Could not write article as html file to \(htmlPath) because \(error)")
        }

        return (htmlPath)
    }

    func uniqueId(for articleText: String) -> String {
        if let data = articleText.data(using: String.Encoding.utf8) {
            var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

            // CC_MD5 performs digest calculation and places the result in the caller-supplied buffer for digest (md)
            // Calls the given closure with a pointer to the underlying unsafe bytes of the data’s contiguous storage.
            _ = data.withUnsafeBytes {
                CC_MD5($0.baseAddress, UInt32(data.count), &digest)
            }

            let md5String = digest
                .map { byte in String(format: "%02x", UInt8(byte)) }
                .reduce(into: "") { result, newValue in result += newValue }
            return md5String
        }
        return ""
    }
}
