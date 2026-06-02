import SwiftUI

// MARK: - Focused ViewModel

private struct FocusedHermesViewModelKey: FocusedValueKey {
    typealias Value = HermesViewModel
}

private struct FocusedNavigationSelectionKey: FocusedValueKey {
    typealias Value = NavigationItem
}

extension FocusedValues {
    /// The shared HermesViewModel, available when the main content area is focused.
    var hermesViewModel: HermesViewModel? {
        get { self[FocusedHermesViewModelKey.self] }
        set { self[FocusedHermesViewModelKey.self] = newValue }
    }

    /// The currently active navigation item in the sidebar.
    var navigationSelection: NavigationItem? {
        get { self[FocusedNavigationSelectionKey.self] }
        set { self[FocusedNavigationSelectionKey.self] = newValue }
    }
}
