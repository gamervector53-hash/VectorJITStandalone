import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: JITModel
    @State private var importer = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Pairing record") {
                    Label(model.pairingName, systemImage: "link")
                    Button("Import Pairing File") { importer = true }
                    Text("The complete file is copied intact. VectorJIT reads what JIT needs and does not strip fields that may also be used by SideStore or another purpose.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Target") {
                    TextField("PID, e.g. 1234", text: $model.pidText)
                        .keyboardType(.numberPad)
                    Toggle("Force universal iOS 26 script", isOn: $model.forceScript)
                    Text("You can also launch vectorjit://enable?pid=1234 from a target app or Shortcut.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("JIT") {
                    Button {
                        model.prepare()
                    } label: {
                        Label("Prepare Device / DDI", systemImage: "externaldrive.badge.checkmark")
                    }
                    .disabled(model.busy)

                    Button {
                        model.enable()
                    } label: {
                        Label("Enable JIT", systemImage: "bolt.fill")
                    }
                    .disabled(model.busy)

                    Button(role: .destructive) {
                        model.resetDDI()
                    } label: {
                        Label("Reset DDI Cache", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(model.busy)
                }

                Section("Status") {
                    HStack {
                        Text(model.status)
                        Spacer()
                        if model.busy { ProgressView() }
                    }
                    if !model.logs.isEmpty {
                        ScrollView {
                            Text(model.logs.joined(separator: "\n"))
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 160)
                    }
                }

                Section("Requirements") {
                    Text("iOS 17.4+, Developer Mode, a valid pairing record, and the LocalDevVPN/RSD route when required. This app targets another process by PID; it is not StikDebug.")
                        .font(.caption)
                }
            }
            .navigationTitle("VectorJIT")
        }
        .fileImporter(
            isPresented: $importer,
            allowedContentTypes: [.data, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.importPairingFile(from: url) }
            case .failure(let error):
                model.status = "Import failed"
                model.logs.append(error.localizedDescription)
            }
        }
    }
}
