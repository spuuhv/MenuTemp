import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var tempReader = TemperatureReader()
    var cancellable: AnyCancellable?
    var helperProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startHelper() // 启动 C helper
        tempReader.startReading() // 立即开始读取（不需要延迟）

        // 初始化菜单栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "--°C"
        statusItem.menu = NSMenu()

        // 订阅温度变化，刷新 UI
        cancellable = tempReader.$packageTempInt.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshMenu()
            }
        }
    }

    private func startHelper() {
        guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: "monitor_cpu_temp_fifo") else {
            print("【错误】找不到资源中的 C 程序文件")
            return
        }

        // 确保 helper 可执行
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
        } catch {
            print("【警告】设置 C 程序可执行权限失败: \(error)")
        }

        // 传给 helper 的 FIFO 路径
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

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        // 添加温度显示
        menu.addItem(menuItem(for: "封装温度", value: tempReader.packageTempInt))
        menu.addItem(menuItem(for: "核心平均温度", value: tempReader.avgTempInt))
        menu.addItem(menuItem(for: "最低温度", value: tempReader.minTempInt))
        menu.addItem(menuItem(for: "最高温度", value: tempReader.maxTempInt))
        menu.addItem(.separator())
        menu.addItem(createQuitMenuItem())

        // 更新状态栏标题
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

    private func createQuitMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        item.target = self
        return item
    }

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
