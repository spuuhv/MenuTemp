import SwiftUI

@main
struct MenuTempApp: App {
    // 绑定 AppDelegate 来管理状态栏
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 主程序不显示窗口
        Settings {
            EmptyView()
        }
    }
}
