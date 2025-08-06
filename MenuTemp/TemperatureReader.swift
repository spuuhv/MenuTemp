import Foundation
import Combine

final class TemperatureReader: ObservableObject {
    @Published private(set) var packageTempInt: Int? = nil
    @Published private(set) var avgTempInt: Int? = nil
    @Published private(set) var minTempInt: Int? = nil
    @Published private(set) var maxTempInt: Int? = nil

    private let fifoPath = NSTemporaryDirectory() + "cpu_temp_pipe"
    private var fileHandle: FileHandle?
    private var leftoverData = Data()
    private var isReading = false

    func startReading() {
        guard !isReading else { return }
        isReading = true

        openPipe()
    }

    func stopReading() {
        isReading = false
        fileHandle?.readabilityHandler = nil
        try? fileHandle?.close()
        fileHandle = nil
        print("【信息】温度读取已停止")
    }

    private func openPipe() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                self.fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: self.fifoPath))
                print("【信息】管道已打开")
                self.setupReadHandler()
            } catch {
                print("【错误】打开管道失败: \(error)")
            }
        }
    }

    private func setupReadHandler() {
        fileHandle?.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let newData = handle.availableData
            if newData.isEmpty {
                self.stopReading()
                return
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

        let parts = trimmed.split(separator: "|")
        guard parts.count == 2 else { return }

        DispatchQueue.main.async {
            self.packageTempInt = self.cleanTemp(parts[0])
            let temps = parts[1].split(separator: " ")
            if temps.count == 3 {
                self.avgTempInt = self.cleanTemp(temps[0])
                self.minTempInt = self.cleanTemp(temps[1])
                self.maxTempInt = self.cleanTemp(temps[2])
            }
        }
    }

    private func cleanTemp<S: StringProtocol>(_ val: S) -> Int? {
        let cleaned = val.replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespaces)
        return Int(Double(cleaned) ?? -1)
    }
}
