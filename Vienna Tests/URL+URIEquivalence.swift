//
//  URL+URIEquivalence.swift
//  Vienna Tests
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

import Foundation

extension URL {

	///
	/// NSURL equivalency test
	/// http://stackoverflow.com/questions/12310258/reliable-way-to-compare-two-nsurl-or-one-nsurl-and-an-nsstring
	///
	func isEquivalent(_ aURL: URL) -> Bool {
		if self == aURL { return true }

		if self.scheme!.caseInsensitiveCompare(aURL.scheme!) != .orderedSame { return false }
		if self.host!.caseInsensitiveCompare(aURL.host!) != .orderedSame { return false }

		// NSURL path is smart about trimming trailing slashes
		// note case-sensitivty here
		if self.path.compare(aURL.path) != .orderedSame { return false }

		// at this point, we've established that the urls are equivalent according to the rfc
		// insofar as scheme, host, and paths match

		// according to rfc2616, port's can weakly match if one is missing and the
		// other is default for the scheme, but for now, let's insist on an explicit match
		if self.port != nil || aURL.port != nil {
			if !(self.port == aURL.port) { return false }
			if !(self.query == aURL.query) { return false }
		}

		// for things like user/pw, fragment, etc., seems sensible to be
		// permissive about these.
		return true
	}

}
