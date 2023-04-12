//
//  Criteria.swift
//  Vienna
//
//  Copyright 2023 Tassilo Karge
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

enum CriteriaCondition: String {
    case all
    case any
    case invalid
    case none
}

@objc(VNACriteriaOperator)
enum CriteriaOperator: Int {
    case equalTo = 1
    case notEqualTo
    case lessThan
    case greaterThan
    case lessThanOrEqualTo
    case greaterThanOrEqualTo
    case contains
    case containsNot
    case before
    case after
    case onOrBefore
    case onOrAfter
    case under
    case notUnder

    // Workaround as long as this enum needs to be exposed to Objective-C and cannot have a string as raw value
    init?(rawValue: String) {
        let criteriaOperator: CriteriaOperator
        switch rawValue {
        case "\(CriteriaOperator.equalTo)":
            criteriaOperator = CriteriaOperator.equalTo
        case "\(CriteriaOperator.notEqualTo)":
            criteriaOperator = CriteriaOperator.notEqualTo
        case "\(CriteriaOperator.lessThan)":
            criteriaOperator = CriteriaOperator.lessThan
        case "\(CriteriaOperator.greaterThan)":
            criteriaOperator = CriteriaOperator.greaterThan
        case "\(CriteriaOperator.lessThanOrEqualTo)":
            criteriaOperator = CriteriaOperator.lessThanOrEqualTo
        case "\(CriteriaOperator.greaterThanOrEqualTo)":
            criteriaOperator = CriteriaOperator.greaterThanOrEqualTo
        case "\(CriteriaOperator.contains)":
            criteriaOperator = CriteriaOperator.contains
        case "\(CriteriaOperator.containsNot)":
            criteriaOperator = CriteriaOperator.containsNot
        case "\(CriteriaOperator.before)":
            criteriaOperator = CriteriaOperator.before
        case "\(CriteriaOperator.after)":
            criteriaOperator = CriteriaOperator.after
        case "\(CriteriaOperator.onOrBefore)":
            criteriaOperator = CriteriaOperator.onOrBefore
        case "\(CriteriaOperator.onOrAfter)":
            criteriaOperator = CriteriaOperator.onOrAfter
        case "\(CriteriaOperator.under)":
            criteriaOperator = CriteriaOperator.under
        case "\(CriteriaOperator.notUnder)":
            criteriaOperator = CriteriaOperator.notUnder
        default:
            return nil
        }
        self.init(rawValue: criteriaOperator.rawValue)
    }

    var intValue: Int {
        rawValue
    }
}

@objc
protocol CriteriaElement: PredicateConvertible {
}

// Workaround while this variable is needed for objc, due to generics in traverse function
protocol Traversable: CriteriaElement {
    func traverse<ResultType>(treeConversion: (_ element: CriteriaTree, _ subresult: [ResultType]) -> ResultType, criteriaConversion: (_ element: Criteria) -> ResultType) -> ResultType
}

@objc
class CriteriaTree: NSObject, Traversable {
    // Workaround while this variable is needed for objc (Traversable cannot be exposed)
    @objc var criteriaTree: [CriteriaElement] {
        get {
            traversableTree
        }
        set {
            self.traversableTree = newValue as? [Traversable] ?? []
        }
    }

    var condition: CriteriaCondition

    var traversableTree: [Traversable]

    override convenience init() {
        self.init(subtree: [], condition: .all)
    }

    init(subtree: [Traversable], condition: CriteriaCondition) {
        traversableTree = subtree
        self.condition = condition
    }

    func traverse<ResultType>(treeConversion: (_ element: CriteriaTree, _ subresult: [ResultType]) -> ResultType, criteriaConversion: (_ element: Criteria) -> ResultType) -> ResultType {
        let subresult = traversableTree.map {
            if let tree = $0 as? CriteriaTree {
                return tree.traverse(treeConversion: treeConversion, criteriaConversion: criteriaConversion)
            } else if let criteria = $0 as? Criteria {
                return criteria.traverse(treeConversion: treeConversion, criteriaConversion: criteriaConversion)
            } else {
                fatalError("Some new type of element was introduced to criteria tree: \($0)")
            }
        }
        return treeConversion(self, subresult)
    }
}

@objc
class Criteria: NSObject, Traversable {

    @objc var field: String
    @objc var operatorType: CriteriaOperator
    @objc var value: String

    @objc
    init(field: String, operatorType: CriteriaOperator, value: String) {
        self.field = field
        self.operatorType = operatorType
        self.value = value
    }

    func traverse<ResultType>(treeConversion: (_ element: CriteriaTree, _ subresult: [ResultType]) -> ResultType, criteriaConversion: (_ element: Criteria) -> ResultType) -> ResultType {
        return criteriaConversion(self)
    }
}
