import Foundation
import VectorJITCore

@MainActor
final class JITModel: ObservableObject {
    @Published var pidText = ""
    @Published var pairingName = "No pairing file imported"
    @Published var status = "Ready"
    @Published var logs: [String] = []
    @Published var busy = false
    @Published var forceScript = false

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "com.vectorjit.worker", qos: .userInitiated)

    private var appSupport: URL {
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = root.appendingPathComponent("VectorJIT", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var pairingURL: URL { appSupport.appendingPathComponent("pairingFile.plist") }
    var ddiPaths: DDIPaths { .default(in: appSupport) }

    init() {
        if fm.fileExists(atPath: pairingURL.path) {
            pairingName = pairingURL.lastPathComponent
            status = "Pairing file ready"
        }
    }

    func importPairingFile(from source: URL) {
        do {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            let bytes = try Data(contentsOf: source)
            try bytes.write(to: pairingURL, options: .atomic)
            pairingName = source.lastPathComponent
            status = "Imported intact pairing record"
            append("Pairing file copied byte-for-byte. No keys or secondary-purpose fields were removed.")
        } catch {
            status = "Pairing import failed"
            append(error.localizedDescription)
        }
    }

    func prepare() {
        guard fm.fileExists(atPath: pairingURL.path) else {
            status = "Import a pairing file first"; return
        }
        run("Preparing device") { [pairingURL, ddiPaths] in
            let readiness = StikJIT.prepareDevice(
                pairingFile: pairingURL,
                paths: ddiPaths,
                progress: { stage in
                    Task { @MainActor in self.append(Self.stageText(stage)) }
                }
            )
            switch readiness {
            case .ready(let security):
                let txm = security.isTXMPresent.map { $0 ? "present" : "not present" } ?? "unknown"
                Task { @MainActor in
                    self.status = "Device ready"
                    self.append("DDI ready. TXM/SPTM: \(txm)")
                }
            case .unreachable(let reason):
                throw JITFailure(reason)
            case .preparationFailed(let reason):
                throw JITFailure(reason)
            }
        }
    }

    func enable() {
        guard let pid = Int32(pidText), pid > 0 else {
            status = "Enter a valid target PID"; return
        }
        guard fm.fileExists(atPath: pairingURL.path) else {
            status = "Import a pairing file first"; return
        }

        run("Enabling JIT for PID \(pid)") { [pairingURL, ddiPaths, forceScript] in
            try StikJIT.enableJIT(
                targetPID: pid,
                pairingFile: pairingURL,
                ddiPaths: ddiPaths,
                script: .universal,
                forceScript: forceScript,
                preparationProgress: { stage in
                    Task { @MainActor in self.append(Self.stageText(stage)) }
                },
                progress: { line in
                    Task { @MainActor in self.append(line) }
                }
            )
            Task { @MainActor in
                self.status = "JIT request completed"
                self.append("JIT enabled for PID \(pid).")
            }
        }
    }

    func resetDDI() {
        do {
            try StikJIT.resetCachedDDI(at: ddiPaths)
            status = "DDI cache reset"
            append("Developer Disk Image cache removed.")
        } catch {
            status = "DDI reset failed"
            append(error.localizedDescription)
        }
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "vectorjit" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let value = items.first(where: { $0.name == "pid" })?.value {
            pidText = value
            append("Received PID \(value) from URL.")
        }
        if url.host == "enable" { enable() }
    }

    private func run(_ title: String, work: @escaping () throws -> Void) {
        guard !busy else { return }
        busy = true
        status = title
        append(title)
        queue.async {
            do { try work() }
            catch {
                Task { @MainActor in
                    self.status = "Failed"
                    self.append(error.localizedDescription)
                }
            }
            Task { @MainActor in self.busy = false }
        }
    }

    private func append(_ text: String) {
        logs.append(text)
        if logs.count > 150 { logs.removeFirst(logs.count - 150) }
    }

    nonisolated private static func stageText(_ stage: StikJIT.PreparationStage) -> String {
        switch stage {
        case .checkingReachability: return "Checking RSD tunnel…"
        case .checkingDDI: return "Checking Developer Disk Image…"
        case .downloadingDDI(let fraction, let text): return "DDI \(Int(fraction * 100))% — \(text)"
        case .mountingDDI(let fraction): return "Mounting DDI \(Int(fraction * 100))%"
        case .verifyingDDI: return "Verifying DDI…"
        case .ready: return "Device preparation complete."
        }
    }
}

struct JITFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
