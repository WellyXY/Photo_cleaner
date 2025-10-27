import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedProduct: Product?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Features
                        featuresSection
                        
                        // Pricing Plans
                        pricingSection
                        
                        // Purchase Button
                        purchaseButton
                        
                        // Restore & Terms
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .navigationBarHidden(true)
        .overlay(
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.telkaTitle2)
                            .foregroundColor(.gray)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                Spacer()
            }
        )
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(purchaseManager.errorMessage ?? "An error occurred")
        }
        .onAppear {
            // Pre-select the yearly plan (best value)
            if let yearlyProduct = purchaseManager.products.first(where: { $0.id == ProductIdentifier.yearlyPro.rawValue }) {
                selectedProduct = yearlyProduct
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon
            Image(systemName: "photo.on.rectangle.angled")
                .font(.telkaRegular(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Upgrade to Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Unlock unlimited photo processing and premium features")
                    .font(.telkaTitle3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 16) {
            Text("What you'll get:")
                .font(.telkaHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(ProductIdentifier.monthlyPro.features, id: \.self) { feature in
                    FeatureCard(feature: feature)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 16) {
            Text("Choose your plan:")
                .font(.telkaHeadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if purchaseManager.isLoading {
                ProgressView("Loading plans...")
                    .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    ForEach(purchaseManager.products, id: \.id) { product in
                        PricingCard(
                            product: product,
                            isSelected: selectedProduct?.id == product.id,
                            onTap: {
                                selectedProduct = product
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await purchaseSelectedProduct()
                }
            }) {
                HStack {
                    if purchaseManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(purchaseManager.isLoading ? "Processing..." : "Start Free Trial")
                        .font(.telkaHeadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(selectedProduct == nil || purchaseManager.isLoading)
            
            if let selectedProduct = selectedProduct {
                Text(getTrialText(for: selectedProduct))
                    .font(.telkaCaption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button("Restore Purchases") {
                Task {
                    await purchaseManager.restorePurchases()
                }
            }
            .foregroundColor(.blue)
            .disabled(purchaseManager.isLoading)
            
            HStack(spacing: 20) {
                Button("Privacy Policy") {
                    // Open privacy policy
                }
                .font(.telkaCaption)
                .foregroundColor(.secondary)
                
                Button("Terms of Service") {
                    // Open terms of service
                }
                .font(.telkaCaption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Helper Methods
    private func purchaseSelectedProduct() async {
        guard let product = selectedProduct else { return }
        
        do {
            try await purchaseManager.purchase(product)
            // Purchase successful, dismiss paywall
            presentationMode.wrappedValue.dismiss()
        } catch {
            purchaseManager.errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func getTrialText(for product: Product) -> String {
        if product.id == ProductIdentifier.lifetimePro.rawValue {
            return "One-time purchase • No subscription"
        } else {
            return "3-day free trial, then \(product.displayPrice) per \(product.subscription?.subscriptionPeriod.unit == .month ? "month" : "year")"
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let feature: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.telkaTitle3)
            
            Text(feature)
                .font(.telkaSubheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let onTap: () -> Void
    
    private var productIdentifier: ProductIdentifier? {
        ProductIdentifier(rawValue: product.id)
    }
    
    private var isPopular: Bool {
        product.id == ProductIdentifier.yearlyPro.rawValue
    }
    
    private var savings: String? {
        if product.id == ProductIdentifier.yearlyPro.rawValue {
            return "Save 44%"
        }
        return nil
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(productIdentifier?.displayName ?? product.displayName)
                                .font(.telkaHeadline)
                                .fontWeight(.semibold)
                            
                            if isPopular {
                                Text("POPULAR")
                                    .font(.telkaCaption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                        
                        if let savings = savings {
                            Text(savings)
                                .font(.telkaSubheadline)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.telkaTitle2)
                            .fontWeight(.bold)
                        
                        if product.id != ProductIdentifier.lifetimePro.rawValue {
                            Text("per \(product.subscription?.subscriptionPeriod.unit == .month ? "month" : "year")")
                                .font(.telkaCaption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Text(productIdentifier?.description ?? product.description)
                    .font(.telkaSubheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.blue : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PaywallView()
}

