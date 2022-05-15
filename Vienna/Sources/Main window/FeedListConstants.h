//
//  FeedListConstants.h
//  Vienna
//
//  Copyright 2022 Eitot
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

@import Foundation;

typedef NS_ENUM(NSInteger, VNAFeedListSizeMode) {
    VNAFeedListSizeModeTiny = 1,
    VNAFeedListSizeModeSmall = 2,
    VNAFeedListSizeModeMedium = 3
};

typedef CGFloat VNAFeedListRowHeight NS_TYPED_ENUM;
extern VNAFeedListRowHeight const VNAFeedListRowHeightTiny;
extern VNAFeedListRowHeight const VNAFeedListRowHeightSmall;
extern VNAFeedListRowHeight const VNAFeedListRowHeightMedium;
