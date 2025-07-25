// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import WebKit

protocol BrowserDelegate: AnyObject {
    /// Show the homepage to the user
    /// - Parameters:
    ///   - inline: See showEmbeddedHomepage function in BVC for description
    ///   - toastContainer: The container view for alert shown from share extension in the home page context menu
    ///   - homepanelDelegate: The homepanel delegate for the homepage
    ///   - libraryPanelDelegate:  The library panel delegate for the homepage
    ///   - statusBarScrollDelegate: The delegate that takes care of the status bar overlay scroll
    ///   - overlayManager: The overlay manager for the homepage
    @MainActor
    func showLegacyHomepage(
        inline: Bool,
        toastContainer: UIView,
        homepanelDelegate: HomePanelDelegate,
        libraryPanelDelegate: LibraryPanelDelegate,
        statusBarScrollDelegate: StatusBarScrollDelegate,
        overlayManager: OverlayModeManager
    )

    /// Show the new homepage to the user as part of the homepage rebuild project
    @MainActor
    func showHomepage(
        overlayManager: OverlayModeManager,
        isZeroSearch: Bool,
        statusBarScrollDelegate: StatusBarScrollDelegate,
        toastContainer: UIView
    )

    /// Returns a tool which can be used to get a snapshot of the homepage
    @MainActor
    func homepageScreenshotTool() -> Screenshotable?

    /// Hides or shows the homepage.
    ///
    /// Homepage is added to hierarchy when opening the app when swiping tabs is enabled.
    /// This method hide or show the homepage and it's needed when opening the app
    /// to avoid an homepage flash on the background.
    @MainActor
    func setHomepageVisibility(isVisible: Bool)

    /// Show the private homepage to the user as part of felt privacy
    @MainActor
    func showPrivateHomepage(overlayManager: OverlayModeManager)

    /// Show the webview to navigate
    /// - Parameter webView: When nil, will show the already existing webview
    @MainActor
    func show(webView: WKWebView)

    /// This is called the browser is ready to start navigating,
    /// ensuring we are in the required state to perform deeplinks
    @MainActor
    func browserHasLoaded()

    /// Show the Error page to the user
    @MainActor
    func showNativeErrorPage(overlayManager: OverlayModeManager)
}
