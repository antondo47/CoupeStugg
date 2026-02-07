import SwiftUI
import UIKit

struct PairingView: View {
    @EnvironmentObject var sync: CoupleSyncService
    @State private var codeInput: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Share this code with your partner").font(.headline)
                Text(sync.coupleId).font(.system(size: 32, weight: .bold, design: .rounded))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .contextMenu {
                        Button { UIPasteboard.general.string = sync.coupleId } label: {
                            Label("Copy Code", systemImage: "doc.on.doc")
                        }
                    }

                Divider().padding(.vertical, 10)

                Text("Or join their code").font(.subheadline)
                TextField("Enter partner code", text: $codeInput)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                Button {
                    let trimmed = codeInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        sync.configure(coupleId: trimmed)
                        dismiss()
                    }
                } label: {
                    Text("Join")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Pair Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
