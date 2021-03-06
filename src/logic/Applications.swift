import Cocoa
import ApplicationServices

class Applications {
    static var list = [Application]()
    static var appsObserver = RunningApplicationsObserver()
    static var appsInSubscriptionRetryLoop = [String]()

    static func observeNewWindows() {
        for app in list {
            guard app.runningApplication.isFinishedLaunching else { continue }
            app.observeNewWindows()
        }
    }

    static func initialDiscovery() {
        addInitialRunningApplications()
        observeRunningApplications()
        addInitialRunningApplicationsWindows()
    }

    static func addInitialRunningApplications() {
        addRunningApplications(NSWorkspace.shared.runningApplications)
    }

    static func observeRunningApplications() {
        NSWorkspace.shared.addObserver(Applications.appsObserver, forKeyPath: "runningApplications", options: [.old, .new], context: nil)
    }

    static func addInitialRunningApplicationsWindows() {
        // on initial launch, we use private APIs to bring windows from other spaces into the current space, observe them, then remove them from the current space
        let spaces = Spaces.otherSpaces()
        if spaces.count == 0 {
            Windows.sortByLevel()
            return
        }
        let windows = Spaces.windowsInSpaces(spaces).filter { window in
            return Windows.list.first(where: { $0.cgWindowId == window }) == nil
        }
        if windows.count > 0 {
            CGSAddWindowsToSpaces(cgsMainConnectionId, windows as NSArray, [Spaces.currentSpaceId])
            Applications.observeNewWindows()
            Windows.sortByLevel()
            CGSRemoveWindowsFromSpaces(cgsMainConnectionId, windows as NSArray, [Spaces.currentSpaceId])
            return
        }
        Windows.sortByLevel()
    }

    static func addRunningApplications(_ runningApps: [NSRunningApplication]) {
        for app in filterApplications(runningApps) {
            Applications.list.append(Application(app))
        }
    }

    static func removeRunningApplications(_ runningApps: [NSRunningApplication]) {
        for runningApp in runningApps {
            Applications.list.removeAll(where: { $0.runningApplication.isEqual(runningApp) })
            Windows.list.removeAll(where: { $0.application.runningApplication.isEqual(runningApp) })
        }
        guard Windows.list.count > 0 else { (App.shared as! App).hideUi(); return }
        // TODO: implement of more sophisticated way to decide which thumbnail gets focused on app quit
        Windows.focusedWindowIndex = 1
        (App.shared as! App).refreshOpenUi()
    }

    private static func filterApplications(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
        return apps.filter { $0.activationPolicy != .prohibited || $0.bundleIdentifier == "io.github.hluk.CopyQ" }
    }
}

class RunningApplicationsObserver: NSObject {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        let type = NSKeyValueChange(rawValue: change![.kindKey]! as! UInt)
        switch type {
            case .insertion:
                let apps = change![.newKey] as! [NSRunningApplication]
                debugPrint("OS event", "apps launched", apps.map { ($0.processIdentifier, $0.bundleIdentifier) })
                Applications.addRunningApplications(apps)
            case .removal:
                let apps = change![.oldKey] as! [NSRunningApplication]
                debugPrint("OS event", "apps quit", apps.map { ($0.processIdentifier, $0.bundleIdentifier) })
                Applications.removeRunningApplications(apps)
            default: return
        }
    }
}
