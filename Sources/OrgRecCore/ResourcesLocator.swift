import Foundation

enum OrgRecResources {
    static nonisolated let bundle: Bundle = {
        if let resourcesURL = Bundle.main.resourceURL {
            let embeddedURL = resourcesURL.appendingPathComponent("OrgRec_OrgRecCore.bundle", isDirectory: true)
            if let embedded = Bundle(url: embeddedURL) { return embedded }
        }
        return Bundle.module
    }()
}
