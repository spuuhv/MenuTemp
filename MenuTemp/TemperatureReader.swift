import Foundation
import Combine

final class TemperatureReader: ObservableObject {
    @Published private(set) var packageTempInt: Int? = nil
    @Published private(set) var avgTempInt: Int? = nil
    @Published private(set) var minTempInt: Int? = nil
    @Published private(set) var maxTempInt: Int? = nil

    private let fifoPath = "/tmp/cpu_temp_pipe"
    private var fileHandle: FileHandle?
    private var leftoverData = Data()
    private var isReading = false

    func startReading() {
        guard !isReading else { return }
        isReading = true
        openPipeWithRetry()
    }

    func stopReading() {
        isReading = false
        fileHandle?.readabilityHandler = nil
        try? fileHandle?.close()
        fileHandle = nil
        leftoverData.removeAll()
        print("【信息】温度读取已停止")
    }

    /// 持续重试打开 FIFO，直到连接成功
    private func openPipeWithRetry() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            while self.isReading {
                do {
                    self.fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: self.fifoPath))
                    print("【信息】FIFO 已打开: \(self.fifoPath)")
                    self.setupReadHandler()
                    return
                } catch {
                    print("【警告】等待 FIFO 连接中...")
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
    }

    private func setupReadHandler() {
        fileHandle?.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let newData = handle.availableData

            if newData.isEmpty {
                print("【警告】FIFO 读到空数据，可能写端已关闭")
                self.stopReading()
                return
            }

            // 调试输出原始数据
            if let rawStr = String(data: newData, encoding: .utf8) {
                print("【调试】收到数据: \(rawStr)")
            } else {
                print("【调试】收到数据（无法解码为 UTF-8）: \(newData as NSData)")
            }

            self.processData(newData)
        }
    }

    private func processData(_ data: Data) {
        let combined = leftoverData + data
        if let str = String(data: combined, encoding: .utf8) {
            let lines = str.components(separatedBy: "\n")
            leftoverData = lines.last?.data(using: .utf8) ?? Data()
            for line in lines.dropLast() {
                parseLine(line)
            }
        } else {
            leftoverData = combined
        }
    }

    private func parseLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parts = trimmed.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return }

        let pkg = Int(Double(parts[0]) ?? -1)
        let temps = parts[1].split(whereSeparator: { $0.isWhitespace }).compactMap { Int(Double($0) ?? -1) }

        DispatchQueue.main.async {
            self.packageTempInt = pkg
            if temps.count >= 3 {
                self.avgTempInt = temps[0]
                self.minTempInt = temps[1]
                self.maxTempInt = temps[2]
            }
        }
    }
}
