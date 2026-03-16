//
//  DateWithUnitPredicateEditorRowTemplate.swift
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

/** Copied from NSPredicateEditorRowTemplate documentation:
 NSPredicateEditorRowTemplate is a concrete class, but it has five primitive methods that are called by NSPredicateEditor: templateViews, match(for:), setPredicate(_:), displayableSubpredicates(of:), and predicate(withSubpredicates:). NSPredicateEditorRowTemplate implements all of these methods, but you can override them for custom templates. The primitive methods are used by an instance of NSPredicateEditor as follows.
 First, an instance of NSPredicateEditor is created, and some row templates are set on it—either through a nib file or programmatically. The first thing predicate editor does is ask each of the templates for their views, using templateViews.
 After setting up the predicate editor, you typically send it a objectValue message to restore a saved predicate. NSPredicateEditor needs to determine which of its templates should display each predicate in the predicate tree. It does this by sending each of its row templates a match(for:) message and choosing the one that returns the highest value.
 After finding the best match for a predicate, NSPredicateEditor copies that template to get fresh views, inserts them into the proper row, and then sets the predicate on the template using setPredicate(_:). Within that method, the NSPredicateEditorRowTemplate object must set its views' values to represent that predicate.
 NSPredicateEditorRowTemplate next asks the template for the “displayable sub-predicates” of the predicate by sending a displayableSubpredicates(of:) message. If a template represents a predicate in its entirety, or if the predicate has no subpredicates, it can return nil for this.  Otherwise, it should return a list of predicates to be made into sub-rows of that template's row. The whole process repeats for each sub-predicate.
 At this point, the user sees the predicate that was saved.  If the user then makes some changes to the views of the templates, this causes NSPredicateEditor to recompute its predicate by asking each of the templates to return the predicate represented by the new view values, passing in the subpredicates represented by the sub-rows (an empty array if there are none, or nil if they aren't supported by that predicate type):
 predicate(withSubpredicates:)
 */
@objc(VNADateWithUnitPredicateEditorRowTemplate)
class DateWithUnitPredicateEditorRowTemplate: NSPredicateEditorRowTemplate {

    let unitButton: NSPopUpButton = {
        let unitButton = NSPopUpButton()
        for dateUnit in DateUnit.allCases {
            unitButton.menu?.addItem(withTitle: dateUnit.rawValue, action: nil, keyEquivalent: "")
        }
        return unitButton
    }()

    let menuItemForOperator: [CriteriaOperator: NSMenuItem] = [
        .onOrAfter: NSMenuItem(title: "less than ago", action: nil, keyEquivalent: ""),
        .before: NSMenuItem(title: "more than ago", action: nil, keyEquivalent: "")
    ]

    override init() {
        super.init()
    }

    @objc
    init(leftExpressions: [NSExpression]) {
        super.init(leftExpressions: leftExpressions, rightExpressionAttributeType: .integer16AttributeType, modifier: .direct, operators: [NSNumber(value: NSComparisonPredicate.Operator.equalTo.rawValue)], options: 0)

        guard let operatorButton = templateViews[1] as? NSPopUpButton,
              let operatorMenu = operatorButton.menu else {
            fatalError("cannot access template views")
        }
        operatorMenu.removeAllItems()
        for menuItem in menuItemForOperator.values {
            operatorMenu.addItem(menuItem)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var templateViews: [NSView] {
        let originalTemplateViews: [NSView] = super.templateViews
        return Array(originalTemplateViews[0..<2]) + [unitButton] + Array(originalTemplateViews[2..<originalTemplateViews.count])
    }

    override func match(for predicate: NSPredicate) -> Double {
        if let predicate = predicate as? DatePredicateWithUnit,
           menuItemForOperator.keys.contains(predicate.comparisonOperator) {
            return Double.greatestFiniteMagnitude
        } else {
            return 0
        }
    }

    override func setPredicate(_ predicate: NSPredicate) {

        guard let datePredicate = predicate as? DatePredicateWithUnit else {
            fatalError("This predicate editor template must only match dateWithUnit predicates, see match(for:) method")
        }
        guard let operatorMenuItem = menuItemForOperator[datePredicate.comparisonOperator] else {
            fatalError("This predicate editor template must only match predicates with suitable operators, see match(for:) method and menuItemForOperator dictionary")
        }
        guard let fieldButton = templateViews[0] as? NSPopUpButton,
              let operatorButton = templateViews[1] as? NSPopUpButton,
              let unitButton = templateViews[2] as? NSPopUpButton,
              let numberInputField = templateViews[3] as? NSTextField
        else {
            return
        }

        fieldButton.selectItem(withTitle: datePredicate.field)
        operatorButton.selectItem(withTitle: operatorMenuItem.title)
        numberInputField.intValue = Int32(datePredicate.count)
        unitButton.selectItem(withTitle: datePredicate.unit.rawValue)
    }

    override func displayableSubpredicates(of predicate: NSPredicate) -> [NSPredicate]? {
        nil
    }

    override func predicate(withSubpredicates subpredicates: [NSPredicate]?) -> NSPredicate {
        guard let fieldButton = templateViews[0] as? NSPopUpButton,
              let operatorButton = templateViews[1] as? NSPopUpButton,
              let unitButton = templateViews[2] as? NSPopUpButton,
              let numberInputField = templateViews[3] as? NSTextField,
              let dateUnitString = unitButton.selectedItem?.title,
              let comparisonOperator = menuItemForOperator.first(where: { _, value in
                  operatorButton.selectedItem?.title == value.title
              })?.key,
              let dateUnit = DateUnit(rawValue: dateUnitString),
              let field = fieldButton.selectedItem?.title
        else {
            NSLog("Date predicate could not be constructed, returning 'false' predicate")
            return NSPredicate(value: false)
        }
        let count = UInt(numberInputField.intValue)
        return DatePredicateWithUnit(field: field, comparisonOperator: comparisonOperator, count: count, unit: dateUnit)
    }
}
