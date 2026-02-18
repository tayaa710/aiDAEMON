import Foundation
import IOKit.ps

/// Executor for SYSTEM_INFO commands — retrieves system information (IP, disk, CPU, battery, etc.).
public struct SystemInfo: CommandExecutor {

    public var name: String { "SystemInfo" }

    // MARK: - Supported info types

    /// Known system info targets the LLM may produce.
    enum InfoType: String {
        case ipAddress      = "ip_address"
        case diskSpace      = "disk_space"
        case cpuUsage       = "cpu_usage"
        case battery        = "battery"
        case batteryTime    = "battery_time"
        case memory         = "memory"
        case hostname       = "hostname"
        case osVersion      = "os_version"
        case uptime         = "uptime"
    }

    /// Alias map — LLM output is unpredictable, so we normalise.
    private static let aliases: [String: InfoType] = {
        var map: [String: InfoType] = [:]
        // Canonical
        for t in [InfoType.ipAddress, .diskSpace, .cpuUsage, .battery,
                  .memory, .hostname, .osVersion, .uptime] {
            map[t.rawValue] = t
        }
        // Common aliases
        map["ip"]           = .ipAddress
        map["ip address"]   = .ipAddress
        map["my ip"]        = .ipAddress
        map["public ip"]    = .ipAddress
        map["disk"]         = .diskSpace
        map["disk space"]   = .diskSpace
        map["storage"]      = .diskSpace
        map["free space"]   = .diskSpace
        map["cpu"]          = .cpuUsage
        map["cpu usage"]    = .cpuUsage
        map["processor"]    = .cpuUsage
        map["battery"]        = .battery
        map["battery level"]  = .battery
        map["battery status"] = .battery
        map["power"]          = .battery
        map["battery_time_remaining"] = .batteryTime
        map["battery time remaining"] = .batteryTime
        map["battery time"]           = .batteryTime
        map["time remaining"]         = .batteryTime
        map["time to full"]           = .batteryTime
        map["time to charge"]         = .batteryTime
        map["charging time"]          = .batteryTime
        map["time to empty"]          = .batteryTime
        map["how long to charge"]     = .batteryTime
        map["ram"]          = .memory
        map["ram usage"]    = .memory
        map["memory"]       = .memory
        map["memory usage"] = .memory
        map["host"]         = .hostname
        map["hostname"]     = .hostname
        map["computer name"] = .hostname
        map["os"]           = .osVersion
        map["os version"]   = .osVersion
        map["macos version"] = .osVersion
        map["version"]      = .osVersion
        map["uptime"]       = .uptime
        map["up time"]      = .uptime
        return map
    }()

    /// Resolve a target string to an InfoType.
    static func resolve(_ raw: String) -> InfoType? {
        let key = raw.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "  ", with: " ")
        return aliases[key] ?? aliases[key.replacingOccurrences(of: "_", with: " ")]
    }

    // MARK: - CommandExecutor

    public func execute(_ command: Command, completion: @escaping (ExecutionResult) -> Void) {
        guard let rawTarget = command.target, !rawTarget.isEmpty else {
            completion(.error("No system info type specified.",
                              details: "Supported: ip address, disk space, cpu usage, battery, battery time, memory, hostname, os version, uptime"))
            return
        }

        guard let infoType = SystemInfo.resolve(rawTarget) else {
            completion(.error("Unknown system info type: \(rawTarget)",
                              details: "Supported: ip address, disk space, cpu usage, battery, battery time, memory, hostname, os version, uptime"))
            return
        }

        // Some queries (IP) need network so run on background queue
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.fetch(infoType)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    // MARK: - Fetch Logic

    func fetch(_ type: InfoType) -> ExecutionResult {
        switch type {
        case .ipAddress:   return fetchIPAddress()
        case .diskSpace:   return fetchDiskSpace()
        case .cpuUsage:    return fetchCPUUsage()
        case .battery:     return fetchBattery()
        case .batteryTime: return fetchBatteryTime()
        case .memory:      return fetchMemory()
        case .hostname:    return fetchHostname()
        case .osVersion:   return fetchOSVersion()
        case .uptime:      return fetchUptime()
        }
    }

    // MARK: - IP Address

    private func fetchIPAddress() -> ExecutionResult {
        // Local IP
        var localIP = "unknown"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr {
            var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
            while let ifa = ptr {
                let family = ifa.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    let name = String(cString: ifa.pointee.ifa_name)
                    if name == "en0" || name == "en1" {
                        var addr = ifa.pointee.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&addr, socklen_t(ifa.pointee.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, 0, NI_NUMERICHOST)
                        localIP = String(cString: hostname)
                        break
                    }
                }
                ptr = ifa.pointee.ifa_next
            }
            freeifaddrs(ifaddr)
        }

        // Public IP via a simple HTTP request (no external dependencies)
        var publicIP = "unavailable"
        let semaphore = DispatchSemaphore(value: 0)
        if let url = URL(string: "https://api.ipify.org") {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let task = URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data, let ip = String(data: data, encoding: .utf8) {
                    publicIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                semaphore.signal()
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + 6)
        }

        return .ok("IP Address",
                    details: "Local: \(localIP)\nPublic: \(publicIP)")
    }

    // MARK: - Disk Space

    private func fetchDiskSpace() -> ExecutionResult {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let totalBytes = (attrs[.systemSize] as? Int64) ?? 0
            let freeBytes = (attrs[.systemFreeSize] as? Int64) ?? 0
            let usedBytes = totalBytes - freeBytes

            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            let free = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
            let used = ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
            let pct = totalBytes > 0 ? Int(Double(usedBytes) / Double(totalBytes) * 100) : 0

            return .ok("Disk Space",
                        details: "Total: \(total)\nUsed: \(used) (\(pct)%)\nFree: \(free)")
        } catch {
            return .error("Failed to read disk space: \(error.localizedDescription)")
        }
    }

    // MARK: - CPU Usage

    private func fetchCPUUsage() -> ExecutionResult {
        // Use host_processor_info to get per-CPU ticks
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs,
                                         &cpuInfo,
                                         &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return .error("Failed to read CPU info")
        }

        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser   += info[offset + Int(CPU_STATE_USER)]
            totalSystem += info[offset + Int(CPU_STATE_SYSTEM)]
            totalIdle   += info[offset + Int(CPU_STATE_IDLE)]
        }

        let totalTicks = totalUser + totalSystem + totalIdle
        let usagePct = totalTicks > 0
            ? Double(totalUser + totalSystem) / Double(totalTicks) * 100
            : 0

        // Deallocate
        let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        let cores = ProcessInfo.processInfo.processorCount
        let active = ProcessInfo.processInfo.activeProcessorCount

        return .ok("CPU Usage",
                    details: "Usage: \(String(format: "%.1f", usagePct))%\nCores: \(cores) (\(active) active)")
    }

    // MARK: - Battery

    private func fetchBattery() -> ExecutionResult {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] else {
            return .ok("Battery", details: "No battery detected (desktop Mac)")
        }

        let capacity = desc[kIOPSCurrentCapacityKey as String] as? Int ?? -1
        let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
        let source = (desc[kIOPSPowerSourceStateKey as String] as? String) ?? "Unknown"
        let timeRemaining = desc[kIOPSTimeToEmptyKey as String] as? Int

        var status = isCharging ? "Charging" : "On Battery"
        if source == kIOPSACPowerValue as String && !isCharging {
            status = "Fully Charged"
        }

        var details = "Level: \(capacity)%\nStatus: \(status)"
        if let mins = timeRemaining, mins > 0 {
            let hours = mins / 60
            let remainder = mins % 60
            details += "\nTime remaining: \(hours)h \(remainder)m"
        }

        return .ok("Battery", details: details)
    }

    // MARK: - Battery Time Remaining / Time to Full Charge

    private func fetchBatteryTime() -> ExecutionResult {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] else {
            return .ok("Battery Time", details: "No battery detected (desktop Mac)")
        }

        let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
        let source = (desc[kIOPSPowerSourceStateKey as String] as? String) ?? ""
        let capacity = desc[kIOPSCurrentCapacityKey as String] as? Int ?? -1

        // Fully charged on AC power
        if source == kIOPSACPowerValue as String && !isCharging {
            return .ok("Battery Time", details: "Fully charged (\(capacity)%) — plugged in.")
        }

        if isCharging {
            // Time to full charge
            let timeToFull = desc[kIOPSTimeToFullChargeKey as String] as? Int ?? -1
            if timeToFull > 0 {
                let hours = timeToFull / 60
                let mins = timeToFull % 60
                let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                return .ok("Battery Time", details: "Charging — \(timeStr) until fully charged (\(capacity)% now).")
            } else {
                return .ok("Battery Time", details: "Charging (\(capacity)%) — time to full not available yet.")
            }
        } else {
            // Time remaining on battery
            let timeToEmpty = desc[kIOPSTimeToEmptyKey as String] as? Int ?? -1
            if timeToEmpty > 0 {
                let hours = timeToEmpty / 60
                let mins = timeToEmpty % 60
                let timeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
                return .ok("Battery Time", details: "On battery — \(timeStr) remaining (\(capacity)%).")
            } else {
                return .ok("Battery Time", details: "On battery (\(capacity)%) — time estimate not available yet.")
            }
        }
    }

    // MARK: - Memory

    private func fetchMemory() -> ExecutionResult {
        let totalBytes = Int64(ProcessInfo.processInfo.physicalMemory)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .memory)

        // Get VM statistics for used/free breakdown
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let pageSize = Int64(vm_kernel_page_size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return .ok("Memory", details: "Total: \(total)\nDetailed info unavailable")
        }

        let activeBytes = Int64(vmStats.active_count) * pageSize
        let wiredBytes = Int64(vmStats.wire_count) * pageSize
        let usedBytes = activeBytes + wiredBytes
        let freeBytes = totalBytes - usedBytes

        let used = ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .memory)
        let free = ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .memory)
        let pct = Int(Double(usedBytes) / Double(totalBytes) * 100)

        return .ok("Memory",
                    details: "Total: \(total)\nUsed: \(used) (\(pct)%)\nAvailable: \(free)")
    }

    // MARK: - Hostname

    private func fetchHostname() -> ExecutionResult {
        let hostname = ProcessInfo.processInfo.hostName
        let computerName = Host.current().localizedName ?? hostname
        return .ok("Hostname",
                    details: "Computer: \(computerName)\nHostname: \(hostname)")
    }

    // MARK: - OS Version

    private func fetchOSVersion() -> ExecutionResult {
        let info = ProcessInfo.processInfo
        let version = info.operatingSystemVersion
        let versionStr = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        // Get macOS marketing name
        let name: String
        switch version.majorVersion {
        case 15: name = "Sequoia"
        case 14: name = "Sonoma"
        case 13: name = "Ventura"
        case 12: name = "Monterey"
        case 11: name = "Big Sur"
        default: name = "macOS"
        }

        let model = getMacModel()

        return .ok("macOS Version",
                    details: "macOS \(name) \(versionStr)\nModel: \(model)")
    }

    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    // MARK: - Uptime

    private func fetchUptime() -> ExecutionResult {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        parts.append("\(minutes)m")

        return .ok("Uptime", details: parts.joined(separator: " "))
    }
}

// MARK: - Debug Tests

#if DEBUG
extension SystemInfo {
    public static func runTests() {
        print("\nRunning SystemInfo tests...")
        var passed = 0
        var failed = 0
        let executor = SystemInfo()

        // Test 1: Executor name
        if executor.name == "SystemInfo" {
            print("  ✅ Test 1: Executor name is 'SystemInfo'")
            passed += 1
        } else {
            print("  ❌ Test 1: Expected 'SystemInfo', got '\(executor.name)'")
            failed += 1
        }

        // Test 2: All canonical targets resolve
        let canonicals = ["ip_address", "disk_space", "cpu_usage", "battery",
                          "memory", "hostname", "os_version", "uptime"]
        var allResolved = true
        for t in canonicals {
            if SystemInfo.resolve(t) == nil {
                print("  ❌ Test 2: Failed to resolve '\(t)'")
                allResolved = false
            }
        }
        if allResolved {
            print("  ✅ Test 2: All 8 canonical targets resolve")
            passed += 1
        } else {
            failed += 1
        }

        // Test 3: Aliases resolve correctly
        let aliasTests: [(String, InfoType)] = [
            ("ip", .ipAddress),
            ("my ip", .ipAddress),
            ("disk", .diskSpace),
            ("storage", .diskSpace),
            ("cpu", .cpuUsage),
            ("ram", .memory),
            ("os", .osVersion),
            ("computer name", .hostname),
        ]
        var aliasOK = true
        for (alias, expected) in aliasTests {
            guard let resolved = SystemInfo.resolve(alias) else {
                print("  ❌ Test 3: Alias '\(alias)' did not resolve")
                aliasOK = false
                continue
            }
            if resolved != expected {
                print("  ❌ Test 3: Alias '\(alias)' resolved to \(resolved) instead of \(expected)")
                aliasOK = false
            }
        }
        if aliasOK {
            print("  ✅ Test 3: All aliases resolve correctly")
            passed += 1
        } else {
            failed += 1
        }

        // Test 4: Unknown target returns nil
        if SystemInfo.resolve("foobar_nonsense") == nil {
            print("  ✅ Test 4: Unknown target returns nil")
            passed += 1
        } else {
            print("  ❌ Test 4: Unknown target should return nil")
            failed += 1
        }

        // Test 5: Hyphen/underscore/case normalisation
        let normTests = ["ip-address", "IP_ADDRESS", "Disk Space", "CPU-USAGE"]
        var normOK = true
        for t in normTests {
            if SystemInfo.resolve(t) == nil {
                print("  ❌ Test 5: Failed to resolve '\(t)'")
                normOK = false
            }
        }
        if normOK {
            print("  ✅ Test 5: Hyphen/underscore/case normalisation works")
            passed += 1
        } else {
            failed += 1
        }

        // Test 6: Missing target returns error
        do {
            let cmd = Command(type: .SYSTEM_INFO, target: nil, confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            executor.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()
            if let r = testResult, !r.success {
                print("  ✅ Test 6: Missing target returns error")
                passed += 1
            } else {
                print("  ❌ Test 6: Missing target should return error")
                failed += 1
            }
        }

        // Test 7: Unknown target returns error
        do {
            let cmd = Command(type: .SYSTEM_INFO, target: "foobar", confidence: 0.9)
            let group = DispatchGroup()
            var testResult: ExecutionResult?
            group.enter()
            executor.execute(cmd) { result in
                testResult = result
                group.leave()
            }
            group.wait()
            if let r = testResult, !r.success, r.message.contains("Unknown") {
                print("  ✅ Test 7: Unknown target returns descriptive error")
                passed += 1
            } else {
                print("  ❌ Test 7: Unknown target should return descriptive error")
                failed += 1
            }
        }

        // Tests 8-12: Call fetch() directly to avoid main-queue deadlock
        // (execute() dispatches to background then completes on main queue,
        //  but tests run on main queue, so DispatchGroup.wait() would deadlock)

        // Test 8: Disk space returns success with details
        do {
            let r = executor.fetch(.diskSpace)
            if r.success, let d = r.details, d.contains("Total") {
                print("  ✅ Test 8: Disk space returns success with details")
                passed += 1
            } else {
                print("  ❌ Test 8: Disk space should return details with 'Total'")
                failed += 1
            }
        }

        // Test 9: OS version returns success
        do {
            let r = executor.fetch(.osVersion)
            if r.success, let d = r.details, d.contains("macOS") {
                print("  ✅ Test 9: OS version returns success with macOS info")
                passed += 1
            } else {
                print("  ❌ Test 9: OS version should contain 'macOS'")
                failed += 1
            }
        }

        // Test 10: Hostname returns success
        do {
            let r = executor.fetch(.hostname)
            if r.success, let d = r.details, !d.isEmpty {
                print("  ✅ Test 10: Hostname returns non-empty result")
                passed += 1
            } else {
                print("  ❌ Test 10: Hostname should return non-empty result")
                failed += 1
            }
        }

        // Test 11: Uptime returns success
        do {
            let r = executor.fetch(.uptime)
            if r.success, let d = r.details, d.contains("m") {
                print("  ✅ Test 11: Uptime returns formatted duration")
                passed += 1
            } else {
                print("  ❌ Test 11: Uptime should contain formatted duration")
                failed += 1
            }
        }

        // Test 12: Memory returns success
        do {
            let r = executor.fetch(.memory)
            if r.success, let d = r.details, d.contains("Total") {
                print("  ✅ Test 12: Memory returns success with total")
                passed += 1
            } else {
                print("  ❌ Test 12: Memory should contain 'Total'")
                failed += 1
            }
        }

        // Test 13: End-to-end parse → dispatch
        do {
            let json = #"{"type": "SYSTEM_INFO", "target": "ip_address", "confidence": 0.95}"#
            let cmd = try! CommandParser.parse(json)
            if cmd.type == .SYSTEM_INFO && cmd.target == "ip_address" {
                print("  ✅ Test 13: End-to-end parse SYSTEM_INFO command")
                passed += 1
            } else {
                print("  ❌ Test 13: Parse returned unexpected result")
                failed += 1
            }
        }

        print("\nSystemInfo results: \(passed) passed, \(failed) failed\n")
    }
}
#endif
