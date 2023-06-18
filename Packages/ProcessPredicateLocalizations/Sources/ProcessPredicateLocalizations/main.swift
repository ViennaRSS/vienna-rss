//
//  main.swift
//  Vienna
//
//  Copyright 2022 Tassilo Karge
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

let arguments = CommandLine.arguments

enum Mode: String {
    case combine = "combine"
    case expand = "expand"
    case compare = "compare"
}

guard arguments.count == 2
        || arguments.count == 3 && [Mode.combine.rawValue, Mode.expand.rawValue].contains(arguments[1])
        || arguments.count == 4 && arguments[1] == Mode.compare.rawValue else {
    fatalError("The program must be called with the following arguments:\n[\(Mode.combine)|\(Mode.expand)] <filename>\n"
               + "or\n\(Mode.compare) <keyfile> <base_stringsfile>")
}

let stringsFileName = arguments[arguments.count - 1]
let mode = arguments.count == 2 ? Mode.combine : Mode(rawValue: arguments[1])!

typealias TranslationWithOptions = (leftOptions: [String], rightOptions: [(num: Int, opt: String)], translation: (original: Substring, translation: Substring))

func output(_ translations: [String]) throws {
    for translationString in translations {
        print(translationString)
    }
}

func parseAndExpand(fileName: String) throws -> [Int: [TranslationWithOptions]] {
    let localizedStrings = try String(contentsOfFile: fileName, encoding: .utf8)

    var lines: [String] = []
    localizedStrings.enumerateLines { line, stop in
        lines.append(line)
    }

    lines = lines.filter { line in
        !line.starts(with: "/*") && !line.isEmpty
    }

    let translationSplitRegex = /^\"(?<original>.*)\" = \"(?<translation>.*)\";$/

    let translations = lines
        .map { line in line.firstMatch(of: translationSplitRegex) }
        .filter { splitLine in splitLine != nil }
        .map { $0! }

    let optionRegex = /\%((?<num>[0-9]*)\$)?\[(?<opt>[^@]*)\]\@/

    let leftSideOptions = translations
        .map { translation in translation.original }
        .map { original in original.matches(of: optionRegex)
            .map { $0.opt } }


    let rightSideOptions = translations
        .map { translation in translation.translation }
        .map { translation in translation.matches(of: optionRegex)
            .map { (num: Int($0.num!)!, opt: $0.opt) } }

    //check if numbers of translations matches on both sides
    for i in 0..<leftSideOptions.count {
        guard leftSideOptions[i].count == rightSideOptions[i].count,
              rightSideOptions[i].map({ $0.num }).sorted().elementsEqual(1...rightSideOptions[i].count) else {
            fatalError("Not all options were translated: \(i): \(leftSideOptions[i]) <-> \(rightSideOptions[i])")
        }
    }

    let unifiedTranslations = translations
        .map { translation in
            (original: translation.original.replacing(optionRegex, with: { regexMatch in "%x" }),
             translation: translation.translation.replacing(optionRegex, with: { regexMatch in "%\(regexMatch.num!)" }))
        }

    let translationsWithOptionsRaw: [TranslationWithOptions] = (0..<translations.count)
        .map { (leftOptions: leftSideOptions[$0].map { substr in String(substr) },
                rightOptions: rightSideOptions[$0].map { num, substr in (num, String(substr)) },
                translation: unifiedTranslations[$0]) }

    let translationsWithOptionsUnsorted = translationsWithOptionsRaw
        .flatMap { (leftOptions: [String], rightOptions: [(num: Int, opt: String)], translation: (original: Substring, translation: Substring)) in
            let leftOptionsExpanded = leftOptions.map { $0.split(separator: ",") }
            let rightOptionsExpanded = rightOptions.map { (num: $0.num, opt: $0.opt.split(separator: ",")) }
            var expanded: [TranslationWithOptions] = [(leftOptions, rightOptions, translation)]
            for i in 0..<leftOptionsExpanded.count {
                var furtherExpanded: [TranslationWithOptions] = []
                for toExpand in expanded {
                    for j in 0..<leftOptionsExpanded[i].count {
                        let leftBelow = Array(toExpand.leftOptions[0..<i])
                        let leftToExpand = String(leftOptionsExpanded[i][j])
                        let leftAbove = Array(toExpand.leftOptions[i+1..<toExpand.leftOptions.count])
                        let left = leftBelow + [leftToExpand] + leftAbove
                        let right = toExpand.rightOptions.map {
                            $0.num != (i+1) ? $0 : (num: i+1, opt: String(rightOptionsExpanded.filter { $0.num == i+1 }.first!.opt[j]))
                        }
                        furtherExpanded += [(leftOptions: left, rightOptions: right, translation: toExpand.translation)]
                    }
                }
                expanded = furtherExpanded
            }
            return expanded
    }

    let translationsWithOptions = translationsWithOptionsUnsorted.sorted(by: { $0.leftOptions.lexicographicallyPrecedes($1.leftOptions) })


    return Dictionary(grouping: translationsWithOptions) { $0.leftOptions.count }
}

func combine(translationsWithOptions groupedByNumOptions: [Int: [TranslationWithOptions]]) throws -> [Int: [TranslationWithOptions]] {

    func compare(translation: TranslationWithOptions, with otherTranslation: TranslationWithOptions,
                 forCombiningIndex toCombine: Int, totalNumOptions: Int) -> Bool {
        var matches = translation.translation == otherTranslation.translation
        for optionIndex in 0..<totalNumOptions {
            matches =
            matches && (optionIndex == toCombine
                        || translation.leftOptions[optionIndex] == otherTranslation.leftOptions[optionIndex]
                        && translation.rightOptions.filter { $0.num - 1 == optionIndex }.first!.opt == otherTranslation.rightOptions.filter { $0.num - 1 == optionIndex }.first!.opt)
        }
        return matches
    }

    typealias TranslationWithOptionsKey = String

    func key(forTranslations translation: TranslationWithOptions, combiningAtIndex toCombine: Int) -> TranslationWithOptionsKey {
        //TODO combine left and right options of all translations in group at 0..<combiningAtIndex (if combiningAtIndex > 0)

        let combinedLeftOptions = translation.leftOptions.enumerated()
            .filter { $0.offset != toCombine }
            .map { $0.element }
            .joined(separator: ",")
        let combinedRightOptions = translation.rightOptions
            .filter { ($0.num - 1) != toCombine }
            .map { $0.opt }
            .joined(separator: ",")
        let key = translation.translation.original + " = " + translation.translation.translation
        + " - " + combinedLeftOptions + " = " + combinedRightOptions
        return key
    }

    func combine(_ translationGroupUnsorted: [TranslationWithOptions], atIndex toCombine: Int) -> TranslationWithOptions {
        let translationGroup = translationGroupUnsorted.sorted(using: KeyPathComparator(\.leftOptions[toCombine]))

        let combinedLeftOption = translationGroup
            .map { $0.leftOptions }
            .map { $0[toCombine] }
            .joined(separator: ",")
        var leftOptions = translationGroup[0].leftOptions
        leftOptions[toCombine] = combinedLeftOption

        let combinedRightOption = translationGroup
            .map { ($0.rightOptions.first { num, _ in num - 1 == toCombine })! }
            .map { $0.opt }
            .joined(separator: ",")
        var rightOptions = translationGroup[0].rightOptions
        rightOptions[rightOptions.firstIndex(where: { num, _ in num - 1 == toCombine })!] = (toCombine + 1, combinedRightOption)

        let translation = translationGroup[0].translation
        return (leftOptions: leftOptions, rightOptions: rightOptions, translation: translation)
    }

    var combinedTranslations: [Int: [TranslationWithOptions]] = groupedByNumOptions

    for (numOptions, _) in groupedByNumOptions {
        for optionIndex in 0..<numOptions {
            let translationValues = combinedTranslations[numOptions, default: []]
            let combinable = Dictionary(grouping: translationValues, by: { key(forTranslations: $0, combiningAtIndex: optionIndex) })
            combinedTranslations[numOptions] = combinable.values.map { combine($0, atIndex: optionIndex) }
        }
    }

    return combinedTranslations
}

func render(_ combinedTranslations: [Int : [TranslationWithOptions]]) throws -> [String] {

    var combinedTranslationStrings: [String] = []

    for (numOptions, combinedTranslationList) in combinedTranslations {
        for combinedTranslation in combinedTranslationList {
            var combined = combinedTranslation.translation
            for optionIndex in 0..<numOptions {
                combined.original = combined.original
                    .replacing(/\%x/,
                               with: "%[\(combinedTranslation.leftOptions[optionIndex])]@", maxReplacements: 1)
                combined.translation = combined.translation
                    .replacing(try Regex("\\%\(optionIndex + 1)"),
                               with: "%\(optionIndex + 1)$[\(combinedTranslation.rightOptions.first { num, _ in num - 1 == optionIndex }!.opt)]@")
            }
            combinedTranslationStrings.append("\"\(combined.original)\" = \"\(combined.translation)\";")
        }
    }
    return combinedTranslationStrings
}

let groupedByNumOptions = try parseAndExpand(fileName: stringsFileName)

switch mode {
case .expand:
    try output(render(groupedByNumOptions))
case .combine:
    try output(render(combine(translationsWithOptions: groupedByNumOptions)))
case .compare:
    let keyfileName = arguments[2]
    let firstKeys = Set(try parseAndExpand(fileName: keyfileName).flatMap({ (key: Int, value: [TranslationWithOptions]) in
        value.map { translation in [String(translation.translation.original)] + translation.leftOptions }
    }))
    let secondKeys = Set(try parseAndExpand(fileName: stringsFileName).flatMap({ (key: Int, value: [TranslationWithOptions]) in
        value.map { translation in [String(translation.translation.original)] + translation.leftOptions }
    }))
    let notInSecond = firstKeys.filter { !secondKeys.contains($0) }
    let notInFirst = secondKeys.filter { !firstKeys.contains($0) }

    if notInFirst.isEmpty && notInSecond.isEmpty {
        print("First and second translation file have the same keys")
    } else {
        if !notInSecond.isEmpty {
            print("Keys from first file not in second file:\n\(notInSecond.map { "\t\($0)" }.joined(separator: "\n"))")
        }
        if !notInFirst.isEmpty {
            print("Keys from second file not in first file:\n\(notInFirst.map { "\t\($0)" }.joined(separator: "\n"))")
        }
        exit(EXIT_FAILURE)
    }
}
