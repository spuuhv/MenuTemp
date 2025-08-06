import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var tempReader = TemperatureReader()
    var cancellable: AnyCancellable?
    var helperProcess: Process?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startHelper()

        // 延迟启动读取，确保 FIFO 已创建且写端打开
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.tempReader.startReading()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "--°C"

        let menu = NSMenu()
        menu.addItem(createQuitMenuItem())
        statusItem.menu = menu

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

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)
        } catch {
            print("【警告】设置 C 程序可执行权限失败: \(error)")
        }

        let fifoPath = NSTemporaryDirectory() + "cpu_temp_pipe"

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

        // 清空所有菜单项
        menu.removeAllItems()

        // 添加温度项
        let items = buildTemperatureMenuItems()
        for item in items {
            menu.addItem(item)
        }

        // 添加退出按钮
        menu.addItem(createQuitMenuItem())

        // 更新状态栏标题
        updateStatusBarTitle()
    }

    private func buildTemperatureMenuItems() -> [NSMenuItem] {
        var items = [NSMenuItem]()

        func createItem(title: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            return item
        }

        if let package = tempReader.packageTempInt {
            items.append(createItem(title: "封装温度: \(package)°C"))
        } else {
            items.append(createItem(title: "封装温度: --"))
        }

        if let avg = tempReader.avgTempInt {
            items.append(createItem(title: "核心平均温度: \(avg)°C"))
        }
        if let minT = tempReader.minTempInt {
            items.append(createItem(title: "最低温度: \(minT)°C"))
        }
        if let maxT = tempReader.maxTempInt {
            items.append(createItem(title: "最高温度: \(maxT)°C"))
        }

        if !items.isEmpty {
            items.append(NSMenuItem.separator())
        }

        return items
    }

    private func createQuitMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        item.target = self
        item.isEnabled = true
        return item
    }


    private func updateStatusBarTitle() {
        if let package = tempReader.packageTempInt {
            statusItem.button?.title = "\(package)°C"
        } else {
            statusItem.button?.title = "--°C"
        }
    }


    @objc func quit() {
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
