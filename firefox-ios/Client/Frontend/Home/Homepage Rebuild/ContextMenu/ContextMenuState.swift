// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Shared
import Storage
import Redux

/// A protocol that defines methods for handling bookmark operations.
/// Classes conforming to this protocol can manage adding and removing bookmarks.
/// Since bookmarks are not using Redux, we use this instead of dispatching an action.
protocol BookmarksHandlerDelegate: AnyObject {
    @MainActor
    func addBookmark(urlString: String, title: String?, site: Site?)
    @MainActor
    func removeBookmark(urlString: String, title: String?, site: Site?)
}

/// State to populate actions for the `PhotonActionSheet` view
/// Ideally, we want that view to subscribe to the store and update its state following the redux pattern
/// For now, we will instantiate this state and populate the associated view model instead to avoid
/// increasing scope of homepage rebuild project.
struct ContextMenuState {
    var site: Site?
    var actions: [[PhotonRowActions]] = [[]]

    private let profile: Profile
    private let bookmarkDelegate: BookmarksHandlerDelegate
    private let configuration: ContextMenuConfiguration
    private let windowUUID: WindowUUID
    private let logger: Logger

    weak var coordinatorDelegate: ContextMenuCoordinator?

    init(
        profile: Profile = AppContainer.shared.resolve(),
        bookmarkDelegate: BookmarksHandlerDelegate,
        configuration: ContextMenuConfiguration,
        windowUUID: WindowUUID,
        logger: Logger = DefaultLogger.shared
    ) {
        self.profile = profile
        self.bookmarkDelegate = bookmarkDelegate
        self.configuration = configuration
        self.windowUUID = windowUUID
        self.logger = logger

        guard let site = configuration.site else { return }
        self.site = site

        switch configuration.homepageSection {
        case .topSites:
            actions = [getTopSitesActions(site: site)]
        case .jumpBackIn:
            actions = [getJumpBackInActions(site: site)]
        case .bookmarks:
            actions = [getBookmarksActions(site: site)]
        case .pocket:
            actions = [getPocketActions(site: site)]
        default:
            return
        }
    }

    // MARK: - Top sites item's context menu actions
    private func getTopSitesActions(site: Site) -> [PhotonRowActions] {
        let topSiteActions: [PhotonRowActions]

        switch site.type {
        case .sponsoredSite:
            topSiteActions = getSponsoredTileActions(site: site)
        case .pinnedSite:
            topSiteActions = getPinnedTileActions(site: site)
        default:
            topSiteActions = getOtherTopSitesActions(site: site)
        }

        return topSiteActions
    }

    private func getPinnedTileActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        return [getRemovePinTopSiteAction(site: site),
                getOpenInNewTabAction(siteURL: siteURL),
                getOpenInNewPrivateTabAction(siteURL: siteURL),
                getRemoveTopSiteAction(site: site),
                getShareAction(siteURL: site.url)]
    }

    private func getSponsoredTileActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        return [getOpenInNewTabAction(siteURL: siteURL),
                getOpenInNewPrivateTabAction(siteURL: siteURL),
                getSettingsAction(),
                getSponsoredContentAction(),
                getShareAction(siteURL: site.url)]
    }

    private func getOtherTopSitesActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        return [getPinTopSiteAction(site: site),
                getOpenInNewTabAction(siteURL: siteURL),
                getOpenInNewPrivateTabAction(siteURL: siteURL),
                getRemoveTopSiteAction(site: site),
                getShareAction(siteURL: site.url)]
    }

    /// This action removes the tile out of the top sites.
    /// If site is pinned, it removes it from pinned and remove from top sites in general.
    private func getRemoveTopSiteAction(site: Site) -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID

        return SingleActionViewModel(
            title: .RemoveContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.cross,
            allowIconScaling: true,
            tapHandler: { _ in
                ContextMenuState.dispatchContextMenuAction(
                    windowUUID: windowUUID,
                    site: site,
                    actionType: ContextMenuActionType.tappedOnRemoveTopSite
                )
            }).items
    }

    private func getPinTopSiteAction(site: Site) -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID

        return SingleActionViewModel(
            title: .PinTopsiteActionTitle2,
            iconString: StandardImageIdentifiers.Large.pin,
            allowIconScaling: true,
            tapHandler: { _ in
                ContextMenuState.dispatchContextMenuAction(
                    windowUUID: windowUUID,
                    site: site,
                    actionType: ContextMenuActionType.tappedOnPinTopSite
                )
            }).items
    }

    /// This unpin action removes the top site from the location it's in.
    /// The tile can still appear in the top sites as unpinned.
    private func getRemovePinTopSiteAction(site: Site) -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID

        return SingleActionViewModel(
            title: .UnpinTopsiteActionTitle2,
            iconString: StandardImageIdentifiers.Large.pinSlash,
            allowIconScaling: true,
            tapHandler: { _ in
                ContextMenuState.dispatchContextMenuAction(
                    windowUUID: windowUUID,
                    site: site,
                    actionType: ContextMenuActionType.tappedOnUnpinTopSite
                )
            }).items
    }

    private func getSettingsAction() -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID

        return SingleActionViewModel(title: .FirefoxHomepage.ContextualMenu.Settings,
                                     iconString: StandardImageIdentifiers.Large.settings,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            ContextMenuState.dispatchSettingsAction(windowUUID: windowUUID, section: .topSites)
            store.dispatchLegacy(
                ContextMenuAction(windowUUID: windowUUID, actionType: ContextMenuActionType.tappedOnSettingsAction)
            )
        }).items
    }

    private func getSponsoredContentAction() -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID
        let logger = logger

        return SingleActionViewModel(
            title: .FirefoxHomepage.ContextualMenu.SponsoredContent,
            iconString: StandardImageIdentifiers.Large.helpCircle,
            allowIconScaling: true,
            tapHandler: { _ in
                guard let url = SupportUtils.URLForTopic("sponsor-privacy") else {
                    logger.log(
                        "Unable to retrieve URL for sponsor-privacy, return early",
                        level: .warning,
                        category: .homepage
                    )
                    return
                }
                ContextMenuState.dispatchOpenNewTabAction(
                    windowUUID: windowUUID,
                    siteURL: url,
                    isPrivate: false,
                    selectNewTab: true
                )
                store.dispatchLegacy(
                    ContextMenuAction(windowUUID: windowUUID, actionType: ContextMenuActionType.tappedOnSponsoredAction)
                )
            }).items
    }

    // MARK: - JumpBack In section item's context menu actions
    private func getJumpBackInActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }

        let openInNewTabAction = getOpenInNewTabAction(siteURL: siteURL)
        let openInNewPrivateTabAction = getOpenInNewPrivateTabAction(siteURL: siteURL)
        let shareAction = getShareAction(siteURL: site.url)
        let bookmarkAction = getBookmarkAction(site: site)

        return [openInNewTabAction, openInNewPrivateTabAction, bookmarkAction, shareAction]
    }

    // MARK: - Homepage Bookmarks section item's context menu actions
    private func getBookmarksActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }

        let openInNewTabAction = getOpenInNewTabAction(siteURL: siteURL)
        let openInNewPrivateTabAction = getOpenInNewPrivateTabAction(siteURL: siteURL)
        let shareAction = getShareAction(siteURL: site.url)
        let bookmarkAction = getBookmarkAction(site: site)

        return [openInNewTabAction, openInNewPrivateTabAction, bookmarkAction, shareAction]
    }

    // MARK: - Pocket item's context menu actions
    private func getPocketActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        let openInNewTabAction = getOpenInNewTabAction(siteURL: siteURL)
        let openInNewPrivateTabAction = getOpenInNewPrivateTabAction(siteURL: siteURL)
        let shareAction = getShareAction(siteURL: site.url)
        let bookmarkAction = getBookmarkAction(site: site)

        return [openInNewTabAction, openInNewPrivateTabAction, bookmarkAction, shareAction]
    }

    // MARK: - Default actions
    private func getOpenInNewTabAction(siteURL: URL) -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID

        return SingleActionViewModel(
            title: .OpenInNewTabContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.plus,
            allowIconScaling: true
        ) { _ in
            ContextMenuState.dispatchOpenNewTabAction(
                windowUUID: windowUUID,
                siteURL: siteURL,
                isPrivate: false
            )
            // TODO: FXIOS-10171 - Add telemetry
        }.items
    }

    private func getOpenInNewPrivateTabAction(siteURL: URL) -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let windowUUID = windowUUID
        let section = configuration.homepageSection

        return SingleActionViewModel(
            title: .OpenInNewPrivateTabContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.privateMode,
            allowIconScaling: true
        ) { _ in
            ContextMenuState.dispatchOpenNewTabAction(
                windowUUID: windowUUID,
                siteURL: siteURL,
                isPrivate: true
            )
            ContextMenuState.dispatchContextMenuActionForSection(
                windowUUID: windowUUID,
                section: section,
                actionType: ContextMenuActionType.tappedOnOpenNewPrivateTab
            )
        }.items
    }

    private func getBookmarkAction(site: Site) -> PhotonRowActions {
        let bookmarkAction: SingleActionViewModel
        let isBookmarked = profile.places.isBookmarked(url: site.url).value.successValue ?? false
        if isBookmarked {
            bookmarkAction = getRemoveBookmarkAction(site: site)
        } else {
            bookmarkAction = getAddBookmarkAction(site: site)
        }
        return bookmarkAction.items
    }

    private func getRemoveBookmarkAction(site: Site) -> SingleActionViewModel {
        return SingleActionViewModel(title: .RemoveBookmarkContextMenuTitle,
                                     iconString: StandardImageIdentifiers.Large.bookmarkSlash,
                                     allowIconScaling: true,
                                     tapHandler: { [bookmarkDelegate] _ in
            bookmarkDelegate.removeBookmark(urlString: site.url, title: site.title, site: site)
        })
    }

    private func getAddBookmarkAction(site: Site) -> SingleActionViewModel {
        return SingleActionViewModel(title: .BookmarkContextMenuTitle,
                                     iconString: StandardImageIdentifiers.Large.bookmark,
                                     allowIconScaling: true,
                                     tapHandler: { [bookmarkDelegate] _ in
            // The method in BVC also handles the toast for this use case
            bookmarkDelegate.addBookmark(urlString: site.url, title: site.title, site: site)
        })
    }

    private func getShareAction(siteURL: String) -> PhotonRowActions {
        // TODO: FXIOS-12750 ContextMenuState should be synchronized to the main actor, and then we won't need to pass
        // this state across isolation boundaries...
        let logger = self.logger
        let sourceView = configuration.sourceView ?? UIView()
        let toastContainerView = configuration.toastContainer
        let windowUUID = windowUUID

        return SingleActionViewModel(
            title: .ShareContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.share,
            allowIconScaling: true,
            tapHandler: { _ in
                guard let url = URL(string: siteURL) else {
                    logger.log(
                        "Unable to retrieve URL for \(siteURL), return early",
                        level: .warning,
                        category: .homepage
                    )
                    return
                }
                let shareSheetConfiguration = ShareSheetConfiguration(
                    shareType: .site(url: url),
                    shareMessage: nil,
                    sourceView: sourceView,
                    sourceRect: nil,
                    toastContainer: toastContainerView,
                    popoverArrowDirection: [.up, .down, .left]
                )

                ContextMenuState.dispatchShareSheetAction(
                    windowUUID: windowUUID,
                    shareSheetConfiguration: shareSheetConfiguration
                )
            }).items
    }

    // MARK: Dispatch Actions
    private static func dispatchSettingsAction(windowUUID: WindowUUID, section: Route.SettingsSection) {
        store.dispatchLegacy(
            NavigationBrowserAction(
                navigationDestination: NavigationDestination(.settings(section)),
                windowUUID: windowUUID,
                actionType: NavigationBrowserActionType.tapOnSettingsSection
            )
        )
    }

    private static func dispatchOpenNewTabAction(
        windowUUID: WindowUUID,
        siteURL: URL,
        isPrivate: Bool,
        selectNewTab: Bool = false
    ) {
        store.dispatchLegacy(
            NavigationBrowserAction(
                navigationDestination: NavigationDestination(
                    .newTab,
                    url: siteURL,
                    isPrivate: isPrivate,
                    selectNewTab: selectNewTab
                ),
                windowUUID: windowUUID,
                actionType: NavigationBrowserActionType.tapOnOpenInNewTab
            )
        )
    }

    private static func dispatchShareSheetAction(windowUUID: WindowUUID, shareSheetConfiguration: ShareSheetConfiguration) {
        store.dispatchLegacy(
            NavigationBrowserAction(
                navigationDestination: NavigationDestination(.shareSheet(shareSheetConfiguration)),
                windowUUID: windowUUID,
                actionType: NavigationBrowserActionType.tapOnShareSheet
            )
        )
    }

    private static func dispatchContextMenuAction(windowUUID: WindowUUID, site: Site, actionType: ActionType) {
        store.dispatchLegacy(
            ContextMenuAction(
                site: site,
                windowUUID: windowUUID,
                actionType: actionType
            )
        )
    }

    private static func dispatchContextMenuActionForSection(
        windowUUID: WindowUUID,
        section: HomepageSection,
        actionType: ActionType
    ) {
        store.dispatchLegacy(
            ContextMenuAction(
                section: section,
                windowUUID: windowUUID,
                actionType: actionType
            )
        )
    }
}
