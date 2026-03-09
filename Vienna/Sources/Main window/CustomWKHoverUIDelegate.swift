//
//  CustomWKHoverUIDelegate.swift
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

// TODO: to me it looks like this protocol should be part of the CustomWKUIDelegate, but the unified display view does not declare conformance to that protocol. Probably that is a design flaw in how the unified display view integrates the browser.
@objc
protocol CustomWKHoverUIDelegate {
    @objc
    func hovered(link: String?)
}
