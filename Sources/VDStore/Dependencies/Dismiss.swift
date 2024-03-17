import SwiftUI

extension StoreDIValues {
    
    public var dismiss: () -> Void {
        get { get(\.dismiss, or: _dismiss) }
        set { set(\.dismiss, newValue) }
    }
    
    public var pop: () -> Void {
        get { get(\.pop, or: _pop) }
        set { set(\.pop, newValue) }
    }
}

private func _dismiss() {
    guard let root = UIApplication.shared.windows.first(where: \.isKeyWindow)?.rootViewController else {
        return
    }
    let topController = root.topPresented
    if topController.presentingViewController != nil {
        topController.dismiss(animated: true)
    }
}

private func _pop() {
    guard let root = UIApplication.shared.windows.first(where: \.isKeyWindow)?.rootViewController else {
        return
    }
    let topController = root.topPresented
    if let navController = topController.navController, navController.viewControllers.count > 1 {
        navController.popViewController(animated: true)
    }
}

private extension UIViewController {
    
    var topPresented: UIViewController {
        presentedViewController?.topPresented ?? self
    }
    
    var navController: UINavigationController? {
        (self as? UINavigationController) ?? navigationController ?? children.navController
    }
}

private extension [UIViewController] {
    
    var navController: UINavigationController? {
        for viewController in self {
            if let navController = viewController as? UINavigationController {
                return navController
            }
            if let navController = viewController.children.navController {
                return navController
            }
        }
        return nil
    }
}
