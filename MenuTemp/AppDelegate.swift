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

        let menu = NSMenu()

        // 温度显示占位（索引0~3）
        menu.addItem(menuItem(for: "封装温度", value: nil))
        menu.addItem(menuItem(for: "核心平均温度", value: nil))
        menu.addItem(menuItem(for: "最低温度", value: nil))
        menu.addItem(menuItem(for: "最高温度", value: nil))

        // 分隔符（索引4）
        menu.addItem(.separator())

        // 开机启动菜单项（倒数第二，索引5）
        launchAtLoginMenuItem = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: "")
        launchAtLoginMenuItem.target = self
        launchAtLoginMenuItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(launchAtLoginMenuItem)

        // 退出菜单项（最后一项，索引6）
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu

        cancellable = tempReader.$packageTempInt.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshTemperatureMenuItems()
            }
        }
    }

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

    private func refreshTemperatureMenuItems() {
        guard let menu = statusItem.menu else { return }

        func updateItem(at index: Int, label: String, value: Int?) {
            let text = value != nil ? "\(label): \(value!)°C" : "\(label): --"
            if index < menu.items.count {
                menu.items[index].title = text
            }
        }

        updateItem(at: 0, label: "封装温度", value: tempReader.packageTempInt)
        updateItem(at: 1, label: "核心平均温度", value: tempReader.avgTempInt)
        updateItem(at: 2, label: "最低温度", value: tempReader.minTempInt)
        updateItem(at: 3, label: "最高温度", value: tempReader.maxTempInt)

        if let package = tempReader.packageTempInt {
            statusItem.button?.title = "\(package)°C"
        } else {
            statusItem.button?.title = "--°C"
        }
    }

    private func menuItem(for label: String, value: Int?) -> NSMenuItem {
        let text = value != nil ? "\(label): \(value!)°C" : "\(label): --"
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func isLaunchAtLoginEnabled() -> Bool {
        let helperBundleID = "com.btsun.MenuTempHelper"
        let jobs = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?.takeRetainedValue() as? [[String: Any]]) ?? []
        return jobs.contains { $0["Label"] as? String == helperBundleID }
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let helperBundleID = "com.btsun.MenuTempHelper" 
        let enabled = sender.state == .off
        if SMLoginItemSetEnabled(helperBundleID as CFString, enabled) {
            sender.state = enabled ? .on : .off
            print("开机启动设置为：\(enabled)")
        } else {
            print("开机启动设置失败")
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
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
