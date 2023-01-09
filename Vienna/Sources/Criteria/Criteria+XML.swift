//
//  Criteria+XML.swift
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

extension CriteriaTree {

    static let groupTag = "criteriagroup"
    static let conditionAttribute = "condition"

    static let criteriaTag = "criteria"

    @objc var string: String {
        let xml: XMLElement = traverse { element, subresult in
            let treeElement = XMLElement(name: CriteriaTree.groupTag)
            treeElement.setAttributesWith([CriteriaTree.conditionAttribute: "\(element.condition)"])
            for subElement in subresult {
                treeElement.addChild(subElement)
            }
            return treeElement
        } criteriaConversion: { element in
            let criteriaElement = XMLElement(name: Criteria.criteriaTag)
            criteriaElement.setAttributesWith([Criteria.fieldAttribute: element.field])

            let operatorElement = XMLElement(name: Criteria.operatorTag, stringValue: "\(element.operatorType.intValue)")
            criteriaElement.addChild(operatorElement)

            let valueElement = XMLElement(name: Criteria.valueTag, stringValue: element.value)
            criteriaElement.addChild(valueElement)

            return criteriaElement
        }

        let criteriaDocument = XMLDocument(rootElement: xml)
        criteriaDocument.isStandalone = true
        criteriaDocument.characterEncoding = "UTF-8"
        criteriaDocument.version = "1.0"

        return criteriaDocument.xmlString
    }

    convenience init?(xml: XMLElement?) {
        guard let xml = xml else {
            NSLog("CriteriaTree cannot be initialized from nil xml")
            return nil
        }

        // For backward compatibility, the absence of the condition attribute
        // assumes that we're matching ALL conditions.
        let conditionString = xml.attribute(forName: CriteriaTree.conditionAttribute)?.stringValue ?? ""

        var subtree: [any CriteriaElement] = []
        for child in xml.children ?? [] {
            guard let child = child as? XMLElement,
                  child.name == CriteriaTree.groupTag || child.name == CriteriaTree.criteriaTag else {
                NSLog("Invalid node \(child) in criteria xml discovered.")
                return nil
            }
            let subCriteriaElement: CriteriaElement
            if child.name == CriteriaTree.groupTag {
                guard let subCriteriaTree = CriteriaTree(xml: child) else {
                    NSLog("CriteriaTree cannot be initialized from \(child)")
                    return nil
                }
                subCriteriaElement = subCriteriaTree
            } else {
                guard let subCriterion = Criteria(xml: child) else {
                    NSLog("Criteria cannot be initialized from \(child)")
                    return nil
                }
                subCriteriaElement = subCriterion
            }
            subtree.append(subCriteriaElement)
        }

        self.init()

        self.condition = CriteriaCondition(rawValue: conditionString) ?? .all
        criteriaTree = subtree
    }

    @objc
    convenience init?(string: String) {
        var xmlError: Error?
        var criteriaTreeXml: XMLDocument?
        do {
            criteriaTreeXml = try XMLDocument(xmlString: string)
        } catch {
            xmlError = error
        }
        guard let criteriaTreeXml = criteriaTreeXml else {
            NSLog(xmlError?.localizedDescription ?? "Unknown failure while parsing xml \(string)")
            return nil
        }
        self.init(xml: criteriaTreeXml.rootElement())
    }
}

extension Criteria {

    static let criteriaTag = "criteria"
    static let fieldAttribute = "field"

    static let valueTag = "value"
    static let operatorTag = "operator"

    convenience init?(xml: XMLElement?) {
        guard let xml = xml else {
            NSLog("Criteria cannot be initialized from nil xml")
            return nil
        }
        guard let field = xml.attribute(forName: Criteria.fieldAttribute)?.stringValue,
              let operatorString = xml.elements(forName: Criteria.operatorTag).first?.stringValue,
              let operatorInt = Int(operatorString),
              let operatorType = CriteriaOperator(rawValue: operatorInt),
              let value = xml.elements(forName: Criteria.valueTag).first?.stringValue else {
            NSLog("Cannot initialize criteria from \(xml)")
            return nil
        }

        self.init(field: field, operatorType: operatorType, value: value)
    }
}
