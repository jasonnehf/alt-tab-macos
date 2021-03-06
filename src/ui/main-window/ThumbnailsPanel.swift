import Cocoa

class ThumbnailsPanel: NSPanel, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout {
    var backgroundView: NSVisualEffectView!
    var collectionView: NSCollectionView!
    var app: App?
    var currentScreen: NSScreen?
    static let cellId = NSUserInterfaceItemIdentifier("Cell")

    convenience init(_ app: App) {
        self.init()
        self.app = app
        isFloatingPanel = true
        animationBehavior = .none
        hidesOnDeactivate = false
        hasShadow = false
        titleVisibility = .hidden
        styleMask.remove(.titled)
        backgroundColor = .clear
        makeCollectionView()
        backgroundView = ThumbnailsPanel.makeBackgroundView()
        backgroundView.addSubview(collectionView)
        contentView!.addSubview(backgroundView)
        // 2nd highest level possible; this allows the app to go on top of context menus
        // highest level is .screenSaver but makes drag and drop on top the main window impossible
        level = .popUpMenu
        // helps filter out this window from the thumbnails
        setAccessibilitySubrole(.unknown)
    }

    func show() {
        makeKeyAndOrderFront(nil)
    }

    static func makeBackgroundView() -> NSVisualEffectView {
        let backgroundView = NSVisualEffectView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.material = Preferences.windowMaterial
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer!.cornerRadius = Preferences.windowCornerRadius
        return backgroundView
    }

    func makeCollectionView() {
        collectionView = NSCollectionView()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.collectionViewLayout = makeLayout()
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.register(CollectionViewItem.self, forItemWithIdentifier: ThumbnailsPanel.cellId)
    }

    private func makeLayout() -> CollectionViewFlowLayout {
        let layout = CollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Preferences.interCellPadding
        layout.minimumLineSpacing = Preferences.interCellPadding
        return layout
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return Windows.list.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: ThumbnailsPanel.cellId, for: indexPath) as! CollectionViewItem
        item.view_.updateRecycledCellWithNewContent(Windows.list[indexPath.item],
                { self.app!.focusSelectedWindow(item.view_.window_) },
                { self.app!.thumbnailsPanel!.highlightCell(item) },
                currentScreen!)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        guard indexPath.item < Windows.list.count else { return .zero }
        return NSSize(width: CollectionViewItemView.width(Windows.list[indexPath.item].thumbnail, currentScreen!).rounded(), height: CollectionViewItemView.height(currentScreen!).rounded())
    }

    func highlightCell() {
        collectionView.deselectAll(nil)
        collectionView.selectItems(at: [IndexPath(item: Windows.focusedWindowIndex, section: 0)], scrollPosition: .top)
    }

    func highlightCell(_ cell: CollectionViewItem) {
        let newIndex = collectionView.indexPath(for: cell)!
        if Windows.focusedWindowIndex != newIndex.item {
            collectionView.selectItems(at: [newIndex], scrollPosition: .top)
            collectionView.deselectItems(at: [IndexPath(item: Windows.focusedWindowIndex, section: 0)])
            Windows.focusedWindowIndex = newIndex.item
        }
    }

    func refreshCollectionView(_ screen: NSScreen, _ uiWorkShouldBeDone: Bool) {
        if uiWorkShouldBeDone { self.currentScreen = screen }
        let layout = collectionView.collectionViewLayout as! CollectionViewFlowLayout
        if uiWorkShouldBeDone { layout.currentScreen = screen }
        if uiWorkShouldBeDone { layout.invalidateLayout() }
        if uiWorkShouldBeDone { collectionView.setFrameSize(NSSize(width: ThumbnailsPanel.widthMax(screen).rounded(), height: ThumbnailsPanel.heightMax(screen).rounded())) }
        if uiWorkShouldBeDone { collectionView.reloadData() }
        if uiWorkShouldBeDone { collectionView.layoutSubtreeIfNeeded() }
        if uiWorkShouldBeDone { collectionView.setFrameSize(NSSize(width: layout.widestRow!, height: layout.totalHeight!)) }
        let windowSize = NSSize(width: layout.widestRow! + Preferences.windowPadding * 2, height: layout.totalHeight! + Preferences.windowPadding * 2)
        if uiWorkShouldBeDone { setContentSize(windowSize) }
        if uiWorkShouldBeDone { backgroundView!.setFrameSize(windowSize) }
        if uiWorkShouldBeDone { collectionView.setFrameOrigin(NSPoint(x: Preferences.windowPadding, y: Preferences.windowPadding)) }
    }

    static func widthMax(_ screen: NSScreen) -> CGFloat {
        return screen.frame.width * Preferences.maxScreenUsage - Preferences.windowPadding * 2
    }

    static func heightMax(_ screen: NSScreen) -> CGFloat {
        return screen.frame.height * Preferences.maxScreenUsage - Preferences.windowPadding * 2
    }
}
