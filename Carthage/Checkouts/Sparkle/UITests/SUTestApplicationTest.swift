//
//  SUTestApplicationTest.swift
//  Sparkle
//
//  Created by Mayur Pawashe on 8/27/15.
//  Copyright © 2015 Sparkle Project. All rights reserved.
//

import XCTest

class SUTestApplicationTest: XCTestCase
{
    var testApplicationURL: URL? = nil
    var testApplicationBackupURL: URL? = nil
    var tempDirectoryURL: URL? = nil
    
    func runningTestApplication() -> NSRunningApplication
    {
        // TODO: don't hardcode bundle ID?
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: "org.sparkle-project.SparkleTestApp")
        XCTAssertEqual(runningApplications.count, 1, "More than one or zero running instances of the Test Application are found")
        return runningApplications[0]
    }
    
    override func setUp()
    {
        super.setUp()
        
        let app = XCUIApplication()
        app.launch()
        
        XCTAssertFalse(app.dialogs["alert"].staticTexts["Update succeeded!"].exists, "Update is already installed; please do a clean build")
        
        // We need to grab the app URL so we can back up the app
        // When a successful test is over we'll revert the update
        let testApplicationURL = self.runningTestApplication().bundleURL!
        
        let tempDirectoryURL = try! FileManager.default.url(for: .itemReplacementDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: testApplicationURL, create: true)
        
        let testApplicationBackupURL = tempDirectoryURL.appendingPathComponent(testApplicationURL.lastPathComponent)
        
        try! FileManager.default.copyItem(at: testApplicationURL, to: testApplicationBackupURL)
        
        self.testApplicationURL = testApplicationURL
        self.testApplicationBackupURL = testApplicationBackupURL
        self.tempDirectoryURL = tempDirectoryURL
        
        // when we add more tests we don't want to continue after a failure
        // since a test can fail after the new app has been placed in
        self.continueAfterFailure = false
    }
    
    override func tearDown()
    {
        // Terminate just in case the app hasn't already quit
        XCUIApplication().terminate()
        
        // Revert our update with the original test application
        
        var resultingURL: NSURL? = nil
        try! FileManager.default.replaceItem(at: self.testApplicationURL!, withItemAt: self.testApplicationBackupURL!, backupItemName: nil, options: .usingNewMetadataOnly, resultingItemURL: &resultingURL)
        
        do {
            try FileManager.default.removeItem(at: self.tempDirectoryURL!)
        } catch let error as NSError {
            NSLog("Failed to remove temporary directory \(self.tempDirectoryURL) with error: \(error)")
        }
        
        // The URL we get back from NSFileManager should be the same..
        XCTAssertEqual(self.testApplicationURL, resultingURL as URL?, "Test application was replaced, but at a different location")
        
        super.tearDown()
    }
    
    func testRegularUpdate()
    {
        let app = XCUIApplication()
        let menuBarsQuery = app.menuBars

        menuBarsQuery.menuBarItems["Sparkle Test App"].click()
        
        // If the update window already showed up automatically, this option will be disabled.
        // Even if it's disabled, attempting to click it will do no harm and continue on
        menuBarsQuery.menuItems["Check for Updates…"].click()
        
        // Workaround to make sure we can click the install update button later
        // This workaround is needed if the alert prompts up automatically *before* we manually check for updates
        // I'm not sure why this workaround works or is necessary
        app.dialogs["SUUpdateAlert"].staticTexts["Software Update"].click()
        
        app.dialogs["SUUpdateAlert"].buttons["Install Update"].click()
        app.windows["SUStatus"].buttons["Install and Relaunch"].click()
        
        // Wait for the new updated app to finish launching so we can test if it's the frontmost app
        sleep(3)
        
        // Our new updated app should be launched now. Test if it's the active app
        // We used to run into timing issues where the updated app sometimes may not show up as the frontmost one
        XCTAssertTrue(self.runningTestApplication().isActive)
        
        // Grab another XCUIApplication instance rather than using the old one, just in case
        let updatedApp = XCUIApplication()
        
        // Check if we can click the "Update succeeded!" label rather than using the exists property
        // Checking the exists property doesn't reload the "cache" and as such the UI tests still would think we are
        // referring to the older app. Clicking does force the UI tests to find the new app however
        updatedApp.dialogs["alert"].staticTexts["Update succeeded!"].click()
        
        updatedApp.dialogs["alert"].buttons["OK"].click()
    }
}
