# Vienna RSS Project Documentation

## 📄 High-Level Project Overview

**Title: Vienna RSS Feed Aggregator**

Vienna is a robust, native macOS application designed for advanced content consumption and aggregation. It provides a customizable reading environment for multiple incoming RSS, Atom, and JSON feeds. Its core function acts as a content management system that goes beyond simple feed reading by providing features like predefined filters, content search, Smart Folders, and a largely configurable reading experience.

### Usage Profile:
Vienna is designed for **power users** — such as developers, researchers, content curators, or deeply engaged readers — who manage many diverse sources of information and require organizational tools beyond basic feed viewing. For them, a comprehensive set of keyboard shortcuts facilitates rapid browsing and streamlined reading.

### Key Concepts:
*   **Federation:** Supports connecting directly to external sites or using the OpenReader API, an adaptation of the now deceased Google Reader API.
*   **Readability Focus:** The application prioritizes user experience by providing distinct viewing modes—a list view for quick scanning, and a reader mode that cleans up raw web content.
*   **Extensible Data Layer:** Core functionality is built around structured data models (`Folder`, `Article`) persisted in SQLite. It uses background notification centers to ensure UI components react immediately to data changes without requiring polling.

---
## 🛠 Technology Stack

| Component | Technology |
| :--- | :--- |
| **GUI toolkit** | Cocoa / AppKit |
| **Language** | Objective-C (Core Logic), Swift (UI & Modern Extensions) |
| **Database** | SQLite (via FMDB) |
| **Rendering Engine** | WebKit (`WKWebView`) |
| **Frameworks** | MMTabBarView (Tabs), Sparkle (Updates) |

---
## ⚙ Key Architectural Patterns

### 1. Architecture Pattern: Hybrid MVC + Observer
The application follows a **hybrid Model-View-Controller / Observer** pattern. Core logic is implemented in Objective-C, while the UI layer uses some Swift components. A critical element of this design is the use of `NSNotificationCenter` to create an event-driven flow: changes in the data model automatically trigger view refreshes across the application, decoupling the persistence layer from the UI components.

### 2. Single Source of Truth (SSoT) & Persistence
All permanent, persistent data (feeds, articles, folder structures) is stored within a structured SQLite database layer. The architecture ensures that this database remains the ultimate source of truth for all displayed content and metadata. To optimize performance, a tiered storage approach is used where short-term values are cached/managed in memory while long-term states reside in SQLite. See the [Data Model](./DataModel.md) guide for the complete taxonomy.

The data scheme is described at https://github.com/ViennaRSS/vienna-rss/wiki/Database-Schema

### 3. Data Flow Management
For an in-depth understanding of how raw feeds are acquired, managed through concurrent operations, processed, synchronized with the local database, and cached to ensure high performance — especially the relationship between short-term caching and persistent (long-term) storage — please consult the dedicated guide: [Data Flow Management](./DataFlow.md).

For viewing articles expected by the user, the data flow summary is as follows:
1.  **Request:** A View Controller initiates a request for articles from `ArticleController`, a service layer specifically dedicated to managing the business logic around fetching, filtering, sorting, and organizing articles displayed within a list view. It decouples list management from display components and centralizes article-specific state management away from the View Controller.
2.  **Process:** The service layer (and dependencies like `ArticleConverter`) fetches/computes the necessary data.
3.  **Display:** The View Controller observes this model change and instructs the specific View (`UnifiedDisplayView` or `WebKitArticleView`) to redraw itself based on the received model state.
4.  **Update:** After successful user interaction, the Model data is updated by `ArticleController`.


### 4. UI/UX Layer Interaction
*   **Active Subscribers:** The UI components (`ArticleList`, `FolderView`) are observers listening for notifications like `MA_Notify_FoldersUpdated`.
*   **Component Breakdown:**
    *   **Folder List Pane:** A recursive tree structure (`FoldersTree`) allowing for nested organization.
    *   **Article List Pane:** Supports multiple layout modes: *Split Layout*, *Unified Layout*.
    *   **Browser Module:** A dedicated `WKWebView` based explorer for deep dives into individual articles.

---
## 📂 Project Structure

The application follows a typical macOS app structure, including:

```
.                          # Project root directory 
├── Vienna.xcodeproj       # Xcode project configuration, schemes, targets
├── Documentation          # Technical docs and guidelines
├── Vienna                 # Main application target
│   ├── Sources            # Core Objective-C/Swift source files
│   │   ├── main.m         # App entry point via NSApplication's delegate pattern
│   │   ├── Application    # Core app lifecycle, state management, and root controllers
│   │   ├── Main window    # Primary navigation UI (Views & ViewControllers)
│   │   ├── Database       # SQLite layer: query logic, migrations, OPML handling
│   │   ├── Plug-ins       # Plugin system interface (logic)
│   │   └── Shared         # Generic utility extensions & networking helpers
│   ├── Interfaces         # Cocoa UI view definitions (NSWindowControllers/Panels)
│   └── SharedSupport      # Implementation of standard plugins and styles (.plist)
├── Vienna Tests           # Unit tests (.m files + some .swift files)
├── External               # Low maintenance third-party dependencies
```

---
## 🔧 Third-Party Dependencies

Outside of frameworks managed by Swift Package Manager, specialized third-party modules are maintained in the `External` folder:
*   **`TRVSURLSessionOperation`**: Handles `NSURLSession` into specialized operations.
*   **`autorevision`**: Utility module for handling version control metadata in builds.
*   **`NSURL+CaminoExtensions`**: Needed to handle webloc files.
*   **`DSClickableURLTextField`**: Adds clickable URLs to UI text fields.

---
## 🏭 Build System & Tooling
- **Tooling:** Uses **Xcode** exclusively.
- **Main Scheme:** `Vienna` (Debug build with full assertions).
- with supporting schemes like `Deployment` (used for release builds, as seen in Makefile).

## 🧪 Testing
Tests are contained under `/Vienna Tests/`. They use XCTest frameworks and generally follow the naming convention: `{ComponentName}Tests.*`. This directory is the primary location for validation efforts.

Building and tests running can be combined with the command:
```bash
xcodebuild test -project Vienna.xcodeproj -scheme Vienna
```

---
## 📚 Related Documentation
- [Data model](./DataModel.md)
- [Data Flow Management](./DataFlow.md)
- [Rendering, layouts and WKWebView](./Rendering_Layouts.md)
- [Filters and Smart folders](./SmartFolders.md)
- [Plugins](./Plugins.md)
- [SDK, code style, commit text](./Contributing.md)

---
*End of Architecture Documentation*