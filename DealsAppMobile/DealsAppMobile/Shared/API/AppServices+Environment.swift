import SwiftUI

private struct AppServicesKey: EnvironmentKey {
    static let defaultValue = AppServices.live
}

extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesKey.self] }
        set { self[AppServicesKey.self] = newValue }
    }
}
