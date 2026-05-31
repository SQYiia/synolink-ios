import Foundation

enum Format {
    private static let units = ["B", "KB", "MB", "GB", "TB"]

    static func bytes(_ n: Int64) -> String {
        guard n > 0 else { return "0 B" }
        var i = 0
        var v = Double(n)
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return String(format: i == 0 ? "%.0f %@" : "%.1f %@", v, units[i])
    }

    static func speed(_ n: Int64) -> String { bytes(n) + "/s" }

    static func bytes(_ n: Int) -> String { bytes(Int64(n)) }
    static func speed(_ n: Int) -> String { speed(Int64(n)) }

    static func date(_ timestamp: Int?) -> String {
        guard let ts = timestamp, ts > 0 else { return "—" }
        let d = Date(timeIntervalSince1970: TimeInterval(ts))
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    static func dsmStatus(_ status: String?) -> (label: String, color: String) {
        switch status {
        case "downloading": return ("下载中", "blue")
        case "paused": return ("已暂停", "orange")
        case "finished", "finishing": return ("已完成", "green")
        case "seeding": return ("做种中", "green")
        case "error": return ("错误", "red")
        case "waiting", "hash_checking": return ("等待中", "gray")
        case "running": return ("运行中", "green")
        case "shutdown": return ("已关机", "gray")
        default: return (status ?? "未知", "gray")
        }
    }
}
