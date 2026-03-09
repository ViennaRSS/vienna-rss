//
//  Constants.swift
//  Vienna
//
//  Copyright 2020
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

/// New articles notification method (managed as an array of binary flags)
@objc(VNANewArticlesNotification)
enum NewArticlesNotification: Int {
    case bounce = 2
}

/// Refresh folder options
@objc(VNARefresh)
enum Refresh: Int {
    case redrawList = 0
    case reapplyFilter = 1
    case sortAndRedraw = 3
}

/// Layout styles
@objc(VNALayout)
enum Layout: Int {
    case report = 1
    case condensed = 2
    case unified = 3
}

/// Folders tree sort method
@objc(VNAFolderSort)
enum FolderSort: Int {
    case manual = 0
    case byName = 1
}

/// Empty trash option on quitting
@objc(VNAEmptyTrash)
enum EmptyTrash: Int {
    case none = 0
    case withoutWarning = 1
    case withWarning = 2
}
