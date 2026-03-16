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

class CriteriaXmlConverter {

    @objc
    static func toXml(_ criteriaElement: any CriteriaElement) -> XMLElement {
        guard let criteriaElement = criteriaElement as? any Traversable else {
            fatalError("All CriteriaElement subtypes must be Traversable!")
        }
        return toXml(criteriaElement)
    }

    static func toXml(_ criteriaElement: any Traversable) -> XMLElement {
        return criteriaElement.traverse { element, subresult in
            let criteriaTreeXml = XMLElement(name: CriteriaTree.groupTag)
            criteriaTreeXml.setAttributesWith([CriteriaTree.conditionAttribute: "\(element.condition)"])
            for subElement in subresult {
                criteriaTreeXml.addChild(subElement)
            }
            return criteriaTreeXml
        } criteriaConversion: { element in
            let criteriaXml = XMLElement(name: Criteria.criteriaTag)
            criteriaXml.setAttributesWith([Criteria.fieldAttribute: element.field])

            let operatorElement = XMLElement(name: Criteria.operatorTag, stringValue: "\(element.operatorType.intValue)")
            criteriaXml.addChild(operatorElement)

            let valueElement = XMLElement(name: Criteria.valueTag, stringValue: element.value)
            criteriaXml.addChild(valueElement)

            return criteriaXml
        }
    }

    @objc
    static func from(xml: XMLElement?) -> (any CriteriaElement)? {
        guard let (subtree, condition) = subtreeAndConditionFrom(xml: xml) else {
            return nil
        }
        return CriteriaTree(subtree: subtree, condition: condition)
    }

    static func subtreeAndConditionFrom(xml: XMLElement?) -> (subtree: [any Traversable], condition: CriteriaCondition)? {
        guard let xml = xml else {
            NSLog("CriteriaTree cannot be initialized from nil xml")
            return nil
        }

        // For backward compatibility, the absence of the condition attribute
        // assumes that we're matching ALL conditions.
        let conditionString = xml.attribute(forName: CriteriaTree.conditionAttribute)?.stringValue ?? ""

        var subtree: [any Traversable] = []
        for child in xml.children ?? [] {
            guard let child = child as? XMLElement,
                  child.name == CriteriaTree.groupTag || child.name == CriteriaTree.criteriaTag else {
                NSLog("Invalid node \(child) in criteria xml discovered.")
                return nil
            }
            let subCriteriaElement: any CriteriaElement
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
            guard let subtreeElement = subCriteriaElement as? (any Traversable) else {
                fatalError("All CriteriaElement subtypes must be Traversable!")
            }
            subtree.append(subtreeElement)
        }
        let condition = CriteriaCondition(rawValue: conditionString) ?? .all
        return (subtree: subtree, condition: condition)
    }
}

extension CriteriaTree {

    static let groupTag = "criteriagroup"
    static let conditionAttribute = "condition"

    static let criteriaTag = "criteria"

    @objc var string: String {
        let xml: XMLElement = CriteriaXmlConverter.toXml(self)

        let criteriaDocument = XMLDocument(rootElement: xml)
        criteriaDocument.isStandalone = true
        criteriaDocument.characterEncoding = "UTF-8"
        criteriaDocument.version = "1.0"

        return criteriaDocument.xmlString
    }

    convenience init?(xml: XMLElement?) {
        guard let (subtree, condition) = CriteriaXmlConverter.subtreeAndConditionFrom(xml: xml) else {
            return nil
        }
        self.init(subtree: subtree, condition: condition)
    }

    @objc
    convenience init?(string: String) {
        var xmlError: (any Error)?
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
