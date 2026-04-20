import SwiftUI

struct EditStockView: View {
    @Environment(\.dismiss) private var dismiss

    let holding: StockHolding

    @State private var quantity: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Stock info (read-only)
                VStack(spacing: 8) {
                    Text(holding.companyName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Text(holding.ticker)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(holding.exchange)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 16)

                // Current quantity
                Text("Current: \(holding.quantity) shares")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Quantity input
                VStack(spacing: 8) {
                    Text("New Quantity")
                        .font(.headline)

                    TextField("Enter quantity", text: $quantity)
                        .keyboardType(.numberPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .navigationTitle("Edit Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                quantity = "\(holding.quantity)"
            }
        }
    }

    private var isValid: Bool {
        guard let newQty = Int(quantity), newQty > 0 else { return false }
        return newQty != holding.quantity
    }

    private func saveChanges() {
        guard let newQty = Int(quantity), newQty > 0 else { return }
        holding.quantity = newQty
        dismiss()
    }
}
