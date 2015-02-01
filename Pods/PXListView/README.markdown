PXListView
==========

An optimized list view control for Mac OS X 10.5 and greater. It was created after I wrote [this post][1] on the subject.

PXListView is licensed under the New BSD license.

`PXListView` uses similar optimizations as `UITableView` for the iPhone, by enqueuing and dequeuing `NSView`s which are used to display rows, in order to keep a low memory footprint when there are a large number of rows in the list, yet still allowing each row to be represented  by an `NSView`, which is easier than dealing with cells.

The architecture of the control is based on the list view controls which are present in both [Tweetie][2] (Mac) and [Echofon][3] (Mac).

The project is still very much a work in progress, and as such no documentation exists at current.

How the control works
---------------------

Each row in the list view is displayed using an instance of `PXListViewCell` (which is a subclass of `NSView`). The delegate of `PXListView` responds to three messages in order for the control to function:

1. `numberOfCellsInListView:`
2. `-listView:cellForRow:`
3. `-listView:heightOfRow:`

###Setting up the List View in Interface Builder###
Setting up PXListView in Interface Builder can be accomplished in a few simple steps:

1. Drag an `NSScrollView` to where you want to lay out the List View.
2. Set the class of the `NSScrollView` to `PXListView` in the Identity Inspector.
3. Set the class of the document view of the `NSScrollView` to `PXListViewDocumentView`.
4. With the scroll view's document view selected, alter the resizing mask so that only the bottom and the left anchors are selected.

###Using PXListViewCell###
`PXListViewCell` is an abstract superclass, implementing the bare minimum for such features as cell selection and declaring methods relied on by the list view.

You should create a concrete subclass of `PXListViewCell` when using it in the list view, where `drawRect:` can be overridden to do custom drawing, and properties for cell UI outlets or data can be declared on this subclass. The example project (as part of the repository) shows this. Since `PXListViewCell`s are views, it is easy to use a NIB to design your cell template, and makes adding text fields, buttons, images etc a much simpler process.

###Returning cells###
When responding to `-listView:cellForRow:`, the delegate should first call `-dequeueCellWithReusableIdentifier:` on the list view, passing in the reusable cell identifier, to see if there are any reusable cells available. If this returns `nil` then a new cell can be created using the initializer `initWithReusableIdentifier:` (declared on PXListViewCell). this keeps the memory footprint of the control as low as possible by reusing cells that have been scrolled offscreen, removed from the view hierarchy and cached.

You can also load cells from NIBs easily, by using `PXListViewCell`'s class method `+cellLoadedFromNibNamed:reusableIdentifier:`. This loads the NIB whose name is passed in, and returns the first list view cell it finds. To create a NIB which is compatible with this feature, just create a blank NIB and add a view. Make sure you set its class to your `PXListViewCell` subclass name, layout your cell as you see fit, and save. When you call `+cellLoadedFromNibNamed:reusableIdentifier:` with the name of your NIB, your new cell will be returned autoreleased, which can then be returned from `-listView:cellForRow:`. There is no need to set a File's Owner for your new NIB.


###Live Resize###
`PXListView` has a property, `usesLiveResize` which determines whether the control should be updated continuously during a resize or not. By default, the cells will be updated continuously as the control is resized. Although visually preferable, especially when dealing with large data sets, this can cause the UI to become slow, so this can be turned off by setting the property to `NO`.

###Optimizations###
`PXListView` only keeps in a view hierarchy the minimum of list view cells needed to be performant. When rows are scrolled, new cells are added to the view hierarchy, and a while after rows are scrolled offscreen, the associated cells are removed from the view hierarchy.

Attributions
------------

Thanks to [Mike Abdullah][4] for optimizations related to cell dequeuing.

Thanks to [Uli Kusterer][5] for additions and fixes to PXListView including momentum scrolling, keyboard navigation, changes to variable row heights (using CGFloats), accessibility as well as drag and drop support.

Thanks to [Tom][6] for fixing a memory issue with reloading data. 

##License
PXListView is licensed under the New BSD License, as detailed below (adapted from OSI http://www.opensource.org/licenses/bsd-license.php):


Copyright &copy; 2011, Alex Rozanski.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
- Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

  [1]: http://perspx.com/blog/archives/1427/making-list-views-really-fast/
  [2]: http://www.atebits.com/tweetie-mac/
  [3]: http://www.echofon.com/twitter/mac/
  [4]: http://mikeabdullah.net/
  [5]: http://github.com/uliwitness
  [6]: http://github.com/TvdW