import SwiftUI
import UIKit

/// Pages change only with the Back button (since 1.33, his ask): a finger that slides a little while
/// tapping a number used to swipe the machine page away. Switches off the edge swipe and the
/// swipe-anywhere of iOS 26 for the navigation stack this view sits in.
private struct NoSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Probe { Probe() }
    func updateUIViewController(_ probe: Probe, context: Context) { probe.switchOff() }

    final class Probe: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            switchOff()
        }
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            switchOff()
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            switchOff()
        }
        func switchOff() {
            var vc: UIViewController? = self
            while let v = vc, v.navigationController == nil { vc = v.parent }
            guard let nav = vc?.navigationController else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = false
            // Only an Xcode with the iOS 26 tools knows this; an older one (as on GitHub's test Mac) skips it.
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) { nav.interactiveContentPopGestureRecognizer?.isEnabled = false }
            #endif
        }
    }
}

extension View {
    /// No swipe back on this page: only the Back button leaves it (since 1.33).
    func noSwipeBack() -> some View {
        background(NoSwipeBack().frame(width: 0, height: 0).accessibilityHidden(true))
    }
}
