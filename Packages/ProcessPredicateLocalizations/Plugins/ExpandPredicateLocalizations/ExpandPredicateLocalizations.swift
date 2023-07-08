//
//  ExpandPredicateLocalizations.swift
//  ProcessPredicateLocalizations
//
//  Copyright 2023
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
import PackagePlugin
import XcodeProjectPlugin

let targetDisplayName = "Vienna"
let baseLocalization = "Base.lproj"
let stringsFileName = "Predicates.strings"
let toolName = "ProcessPredicateLocalizations"
let toolMode = "expand"

@main
struct ExpandPredicateLocalizations: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        throw PluginDeserializationError.internalError("Not implemented")
    }

}

extension ExpandPredicateLocalizations: XcodeCommandPlugin {

    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        guard
            let target = context.xcodeProject.targets.first(where: { target in
                target.displayName == targetDisplayName
            })
        else {
            Diagnostics.error("This plug-in only works for the \(targetDisplayName) target")
            return
        }

        let stringsFiles = target.inputFiles.filter { file in
            file.path.lastComponent == stringsFileName
        }

        let tool = try context.tool(named: toolName)
        for stringsFile in stringsFiles {
            do {
                let process = Process()
                process.executableURL = URL(
                    fileURLWithPath: tool.path.string,
                    isDirectory: false
                )
                let filePath = stringsFile.path.string
                process.arguments = [toolMode, filePath]
                let outputPipe = Pipe()
                process.standardOutput = outputPipe

                Diagnostics.remark("Process file: \(stringsFile.path)")
                try process.run()
                process.waitUntilExit()

                let outputData = try outputPipe.fileHandleForReading.readToEnd()
                if !FileManager.default.createFile(
                    atPath: filePath,
                    contents: outputData
                ) {
                    Diagnostics.error("Failed to change file \(stringsFile.path)")
                }
            } catch {
                Diagnostics.error("Failed to process file \(stringsFile.path)")
            }
        }
    }

}
