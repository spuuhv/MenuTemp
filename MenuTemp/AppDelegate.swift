import Cocoa
import Combine
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var tempReader = TemperatureReader()
    var cancellable: AnyCancellable?
    var helperProcess: Process?

    var launchAtLoginMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        startHelper()
        tempReader.startReading()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "--°C"

        // 初始化菜单
        let menu = NSMenu()

        // 固定四个温度项（初始空值）
        menu.addItem(menuItem(for: "封装温度", value: nil))
        menu.addItem(menuItem(for: "核心平均温度", value: nil))
        menu.addItem(menuItem(for: "最低温度", value: nil))
        menu.addItem(menuItem(for: "最高温度", value: nil))
        menu.addItem(.separator())

        // 开机启动
        launchAtLoginMenuItem = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginMenuItem)

        // 退出
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        // 订阅温度变化
        cancellable = tempReader.$packageTempInt.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshMenu()
            }
        }
    }

    // 启动 helper
    private func startHelper() {
        guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: "monitor_cpu_temp_fifo") else {
            print("【错误】找不到资源中的 C 程序文件")
            return
        }

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
        } catch {
            print("【警告】设置 C 程序可执行权限失败: \(error)")
        }

        let fifoPath = "/tmp/cpu_temp_pipe"

        let process = Process()
        process.executableURL = helperURL
        process.arguments = [fifoPath]
        process.standardOutput = nil
        process.standardError = nil

        do {
            try process.run()
            helperProcess = process
            print("【信息】启动 C 程序成功，PID = \(process.processIdentifier)")
        } catch {
            print("【错误】启动 C 程序失败: \(error)")
        }
    }

    // 刷新温度项（固定顺序）
    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }

        // 更新四个温度项
        menu.item(at: 0)?.title = formattedMenuTitle("封装温度", value: tempReader.packageTempInt)
        menu.item(at: 1)?.title = formattedMenuTitle("核心平均温度", value: tempReader.avgTempInt)
        menu.item(at: 2)?.title = formattedMenuTitle("最低温度", value: tempReader.minTempInt)
        menu.item(at: 3)?.title = formattedMenuTitle("最高温度", value: tempReader.maxTempInt)

        // 更新状态栏显示
        if let package = tempReader.packageTempInt {
            statusItem.button?.title = "\(package)°C"
        } else {
            statusItem.button?.title = "--°C"
        }
    }

    private func formattedMenuTitle(_ label: String, value: Int?) -> String {
        if let v = value {
            return "\(label): \(v)°C"
        } else {
            return "\(label): --"
        }
    }

    private func menuItem(for label: String, value: Int?) -> NSMenuItem {
        let item = NSMenuItem(title: formattedMenuTitle(label, value: value), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // 判断开机启动是否启用
    func isLaunchAtLoginEnabled() -> Bool {
        let helperBundleID = "com.btsun.MenuTempHelper" // 修改成你 Helper 的 Bundle ID

        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            let jobs = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: Any]]) ?? []
            return jobs.contains { $0["Label"] as? String == helperBundleID }
        }
    }

    // 切换开机启动
    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let helperBundleID = "com.btsun.MenuTempHelper"
        let enable = sender.state == .off

        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                sender.state = enable ? .on : .off
                print("开机启动设置为：\(enable)")
            } catch {
                print("开机启动设置失败: \(error)")
            }
        } else {
            if SMLoginItemSetEnabled(helperBundleID as CFString, enable) {
                sender.state = enable ? .on : .off
                print("开机启动设置为：\(enable)")
            } else {
                print("开机启动设置失败")
            }
        }
    }

    // 退出
    @objc private func quit() {
        tempReader.stopReading()

        if let process = helperProcess {
            process.terminate()
            process.waitUntilExit()
            print("【信息】结束 C 程序 PID = \(process.processIdentifier)")
        } else {
            _ = try? shell("killall", "monitor_cpu_temp_fifo")
        }

        NSApplication.shared.terminate(nil)
    }

    private func shell(_ args: String...) throws {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        try task.run()
        task.waitUntilExit()
    }
}
