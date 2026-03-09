//
//  ComparePredicateLocalizations.swift
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
let toolMode = "compare"

@main
struct CombinePredicateLocalizations: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        throw PluginDeserializationError.internalError("Not implemented")
    }

}

extension CombinePredicateLocalizations: XcodeCommandPlugin {

    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        guard
            let target = context.xcodeProject.targets.first(where: { target in
                target.displayName == targetDisplayName
            })
        else {
            Diagnostics.error("This plug-in only works for the \(targetDisplayName) target")
            return
        }

        var localizedStringsFiles = [File]()
        var baseStringsFile: File?
        target.inputFiles.forEach { file in
            guard file.path.lastComponent == stringsFileName else {
                return
            }
            if file.path.removingLastComponent().lastComponent == baseLocalization {
                baseStringsFile = file
            } else {
                localizedStringsFiles.append(file)
            }
        }
        guard let baseStringsFile, !localizedStringsFiles.isEmpty else {
            Diagnostics.error("Target \(target.displayName) is missing \(stringsFileName) files")
            return
        }

        let tool = try context.tool(named: toolName)
        for stringsFile in localizedStringsFiles {
            do {
                let process = Process()
                process.executableURL = URL(
                    fileURLWithPath: tool.path.string,
                    isDirectory: false
                )
                process.arguments = [
                    toolMode, baseStringsFile.path.string, stringsFile.path.string,
                ]
                let locale = stringsFile.path.removingLastComponent().stem
                Diagnostics.remark(
                    "Compare \(stringsFileName) (Base) to \(stringsFileName) (\(locale))"
                )
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == EXIT_FAILURE {
                    Diagnostics.error(
                        "File \(stringsFileName) (\(locale)) does not match \(stringsFileName) (Base)"
                    )
                }
            } catch {
                Diagnostics.error("Failed to process file \(stringsFile.path)")
            }
        }
    }

}
