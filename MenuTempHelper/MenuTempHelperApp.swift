import SwiftUI

@main
struct MenuTempHelperApp: App {
    init() {
        DispatchQueue.main.async {
            Self.launchMainApp()
        }
    }

    var body: some Scene {
        // Helper 不显示任何窗口
        Settings { EmptyView() }
    }

    static func launchMainApp() {
        let mainAppBundleID = "com.yourname.MenuTemp" // 替换为你的主 App Bundle ID
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: mainAppBundleID)
        if runningApps.isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: mainAppBundleID) {
                do {
                    try NSWorkspace.shared.launchApplication(at: url, options: [], configuration: [:])
                    print("主 App 启动成功")
                } catch {
                    print("启动主 App 失败: \(error)")
                }
            } else {
                print("找不到主 App 路径")
            }
        } else {
            print("主 App 已经运行")
        }
        NSApp.terminate(nil) // 启动完退出 Helper
    }
}
