// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "ProcessPredicateLocalizations",
    platforms: [.macOS(.v13)],
    products: [
        .plugin(
            name: "CombinePredicateLocalizations",
            targets: ["CombinePredicateLocalizations"]
        ),
        .plugin(
            name: "ComparePredicateLocalizations",
            targets: ["ComparePredicateLocalizations"]
        ),
        .plugin(
            name: "ExpandPredicateLocalizations",
            targets: ["ExpandPredicateLocalizations"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ProcessPredicateLocalizations",
            swiftSettings: [.enableUpcomingFeature("BareSlashRegexLiterals")]
        ),
        .plugin(
            name: "CombinePredicateLocalizations",
            capability: .command(
                intent: .custom(
                    verb: "combine-predicate-localizations",
                    description: "Combines all Predicates.strings files"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "This plug-in modifies all Predicates.strings files in the project."
                    )
                ]
            ),
            dependencies: ["ProcessPredicateLocalizations"]
        ),
        .plugin(
            name: "ComparePredicateLocalizations",
            capability: .command(
                intent: .custom(
                    verb: "compare-predicate-localizations",
                    description: "Compares localized Predicates.strings files to the base file."
                )
            ),
            dependencies: ["ProcessPredicateLocalizations"]
        ),
        .plugin(
            name: "ExpandPredicateLocalizations",
            capability: .command(
                intent: .custom(
                    verb: "expand-predicate-localizations",
                    description: "Expands all Predicates.strings files"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "This plug-in modifies all Predicates.strings files in the project."
                    )
                ]
            ),
            dependencies: ["ProcessPredicateLocalizations"]
        ),
    ]
)
