import SwiftUI
import StoreKit

struct SubscriptionManagementView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPaywall = false
    @State private var showingCancelConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                // Current Status Section
                currentStatusSection
                
                // Usage Statistics
                if !purchaseManager.hasUnlockedPro {
                    usageSection
                }
                
                // Subscription Details
                if purchaseManager.hasUnlockedPro {
                    subscriptionDetailsSection
                }
                
                // Actions Section
                actionsSection
                
                // Support Section
                supportSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Subscription")
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Manage in Settings", role: .destructive) {
                openSubscriptionManagement()
            }
        } message: {
            Text("To cancel your subscription, you'll need to manage it through your Apple ID settings.")
        }
        .onAppear {
            Task {
                await purchaseManager.updateCustomerProductStatus()
            }
        }
    }
    
    // MARK: - Current Status Section
    private var currentStatusSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.headline)
                    
                    Text(purchaseManager.hasUnlockedPro ? "Pro Member" : "Free Plan")
                        .font(.subheadline)
                        .foregroundColor(purchaseManager.hasUnlockedPro ? .green : .secondary)
                }
                
                Spacer()
                
                if purchaseManager.hasUnlockedPro {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                } else {
                    Button("Upgrade") {
                        showingPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Usage Section
    private var usageSection: some View {
        Section("Daily Usage") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Photos Processed Today")
                    Spacer()
                    Text("\(purchaseManager.dailyPhotoCount) / 10")
                        .fontWeight(.medium)
                }
                
                ProgressView(value: Double(purchaseManager.dailyPhotoCount), total: 10.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: purchaseManager.dailyPhotoCount >= 10 ? .red : .blue))
                
                HStack {
                    Text("Remaining Today")
                    Spacer()
                    Text("\(purchaseManager.getRemainingFreePhotos())")
                        .fontWeight(.medium)
                        .foregroundColor(purchaseManager.getRemainingFreePhotos() == 0 ? .red : .primary)
                }
                
                if purchaseManager.getRemainingFreePhotos() == 0 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Daily limit reached. Upgrade to Pro for unlimited processing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Subscription Details Section
    private var subscriptionDetailsSection: some View {
        Section("Subscription Details") {
            ForEach(Array(purchaseManager.purchasedProductIDs), id: \.self) { productID in
                if let product = purchaseManager.products.first(where: { $0.id == productID }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(getProductDisplayName(productID))
                                .font(.headline)
                            Spacer()
                            Text("Active")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        
                        if productID != ProductIdentifier.lifetimePro.rawValue {
                            Text("Next billing: \(getNextBillingDate())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Lifetime access - no recurring billing")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        Section("Actions") {
            if !purchaseManager.hasUnlockedPro {
                Button(action: {
                    showingPaywall = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Upgrade to Pro")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Button(action: {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                    Text("Restore Purchases")
                    if purchaseManager.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(purchaseManager.isLoading)
            
            if purchaseManager.hasUnlockedPro && !isLifetimePurchase() {
                Button(action: {
                    showingCancelConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.red)
                        Text("Manage Subscription")
                    }
                }
            }
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        Section("Support") {
            Link(destination: URL(string: "https://example.com/support")!) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                    Text("Help & Support")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://example.com/privacy")!) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.blue)
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Link(destination: URL(string: "https://example.com/terms")!) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getProductDisplayName(_ productID: String) -> String {
        switch productID {
        case ProductIdentifier.monthlyPro.rawValue:
            return "Monthly Pro"
        case ProductIdentifier.yearlyPro.rawValue:
            return "Yearly Pro"
        case ProductIdentifier.lifetimePro.rawValue:
            return "Lifetime Pro"
        default:
            return "Pro Subscription"
        }
    }
    
    private func getNextBillingDate() -> String {
        // In a real app, you would get this from the subscription status
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let nextBilling = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        return formatter.string(from: nextBilling)
    }
    
    private func isLifetimePurchase() -> Bool {
        return purchaseManager.purchasedProductIDs.contains(ProductIdentifier.lifetimePro.rawValue)
    }
    
    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SubscriptionManagementView()
}

