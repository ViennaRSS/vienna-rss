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

import Foundation

public class WebKitArticleConverter: ArticleConverter {

    override public func initForStyle(at path: URL) {
        copyStyleContent(from: path)
    }

    private func getCachesPath() -> URL {
        let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let directory = URL(fileURLWithPath: cachesPath[0]).appendingPathComponent(Bundle.main.bundleIdentifier ?? "Vienna").appendingPathComponent("article")
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

    func prepareArticleDisplay(_ articles: [Article]) -> (htmlPath: URL, accessPath: URL) {

        guard !articles.isEmpty else {
            fatalError("an empty articles array cannot be presented")
        }

        let articleDirectory = getCachesPath()

        let htmlPath = articleDirectory.appendingPathComponent("article.html")

        let articleHtml: String = self.articleText(from: articles)

        do {
            if FileManager.default.fileExists(atPath: htmlPath.path) {
                try FileManager.default.removeItem(at: htmlPath)
            }
            try articleHtml.write(to: htmlPath, atomically: true, encoding: .utf8)
        } catch {
            fatalError("Could not write article as html file to \(htmlPath) because \(error)")
        }

        return (htmlPath: htmlPath, accessPath: articleDirectory)
    }
}
