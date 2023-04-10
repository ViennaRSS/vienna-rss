//
//  DatePredicateWithUnit.swift
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

enum DateUnit: String, CaseIterable {
    case minutes
    case hours
    case days
    case weeks
    case months
    case years
}

class DatePredicateWithUnit: NSPredicate {

    var field: String
    var comparisonOperator: CriteriaOperator
    var count: UInt
    var unit: DateUnit

    init(field: String, comparisonOperator: CriteriaOperator, count: UInt, unit: DateUnit) {
        self.field = field
        self.comparisonOperator = comparisonOperator
        self.count = count
        self.unit = unit
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func evaluate(with object: Any?) -> Bool {
        guard object is Article else {
            return false //cannot evaluate on objects not of type Article
        }
        return false //TODO: write proper evaluation
    }

    override var predicateFormat: String { "" } //TODO: write proper format string
}
