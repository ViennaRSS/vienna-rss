//
//  Database+CriteriaMigration.swift
//  Vienna
//
//  Copyright 2025 Tassilo Karge
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

extension Database {
    @objc
    func migrateCriteria(from version: Int) {
        switch version + 1 {
        case 0..<27: // xml migration did not exist yet, but we could hit this case if someone jumps a major version
            NSLog("Migration of xml for version < 27")
            fallthrough
        case 27: // migrate criteria from folder names to folder ids
            guard let smartfoldersDict = self.smartfoldersDict as? [Int: CriteriaTree] else {
                NSLog("Criteria conversion to version 27 failed")
                return
            }
            for (folderId, criteriaTree) in smartfoldersDict {

                criteriaTree.traverse(treeModifier: nil, criteriaModifier: { criteria in
                    if criteria.field == MA_Field_Folder {
                        criteria.value = Criteria.convertIndentedFolderNameToFolderId(criteria.value, on: self)
                    }
                })
                self.updateSearchFolder(folderId, withNewFolderName: nil, withQuery: criteriaTree)
            }

            NSLog("Updated smart folder xmls to version 27")
            fallthrough
        // add future migrations (28 and later) here
        default:
            break
        }
    }

    @objc
    func rollbackCriteria(to version: Int) {
        var revertFunctions: [() -> Void] = []
        switch version + 1 {
        // no option to revert beyond version 26
        case 27: // revert migrate criteria from folder names to folder ids
            revertFunctions.append {
                guard let smartfoldersDict = self.smartfoldersDict as? [Int: CriteriaTree] else {
                    NSLog("Criteria conversion to version 27 failed")
                    return
                }
                for (folderId, criteriaTree) in smartfoldersDict {

                    criteriaTree.traverse(treeModifier: nil, criteriaModifier: { criteria in
                        if criteria.field == MA_Field_Folder {
                            criteria.value = Criteria.convertFolderIdToIndentedName(criteria.value)
                        }
                    })
                    self.updateSearchFolder(folderId, withNewFolderName: nil, withQuery: criteriaTree)
                }

                NSLog("Revert update of smart folder xmls of version 27")
            }
            fallthrough
        // add future revert functions (28 and later) here
        default:
            break
        }
        // execute revert functions from latest version to oldest version to arrive at requested version
        revertFunctions.reversed().forEach { $0() }
    }
}
