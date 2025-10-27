import Foundation
import StoreKit
import SwiftUI

// MARK: - Product Identifiers
enum ProductIdentifier: String, CaseIterable {
    case monthlyPro = "com.local.photocleaner.monthly_pro"
    case yearlyPro = "com.local.photocleaner.yearly_pro"
    case lifetimePro = "com.local.photocleaner.lifetime_pro"
    
    var displayName: String {
        switch self {
        case .monthlyPro:
            return "Monthly Pro"
        case .yearlyPro:
            return "Yearly Pro"
        case .lifetimePro:
            return "Lifetime Pro"
        }
    }
    
    var description: String {
        switch self {
        case .monthlyPro:
            return "Unlimited photo processing, premium features"
        case .yearlyPro:
            return "Best value! Save 44% with yearly subscription"
        case .lifetimePro:
            return "One-time purchase, lifetime access to all features"
        }
    }
    
    var features: [String] {
        return [
            "Unlimited photo processing",
            "Advanced AI sorting",
            "Batch operations",
            "Cloud backup integration",
            "Priority customer support",
            "No ads"
        ]
    }
}

// MARK: - Purchase Manager
@MainActor
class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var hasUnlockedPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Free tier limits
    private let freePhotoLimit = 10
    @Published var dailyPhotoCount: Int = 0
    @Published var lastResetDate: Date = Date()
    
    private var updates: Task<Void, Never>? = nil
    
    override init() {
        super.init()
        
        // Load saved state
        loadPurchaseState()
        loadDailyUsage()
        
        // Start listening for transaction updates
        updates = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Product Loading
    func requestProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIdentifiers = ProductIdentifier.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIdentifiers)
            print("✅ Loaded \(products.count) products")
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("❌ Error loading products: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Logic
    func purchase(_ product: Product) async throws {
        isLoading = true
        errorMessage = nil
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            print("✅ Purchase successful: \(product.id)")
            
        case .userCancelled:
            print("🚫 User cancelled purchase")
            
        case .pending:
            print("⏳ Purchase pending")
            
        @unknown default:
            break
        }
        
        isLoading = false
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
            print("✅ Purchases restored")
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            print("❌ Error restoring purchases: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Transaction Verification
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Transaction Updates
    func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Product Status Updates
    func updateCustomerProductStatus() async {
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                switch transaction.productType {
                case .autoRenewable:
                    if let subscriptionStatus = await transaction.subscriptionStatus {
                        if subscriptionStatus.state == .subscribed {
                            purchasedProducts.insert(transaction.productID)
                        }
                    }
                case .nonConsumable:
                    purchasedProducts.insert(transaction.productID)
                default:
                    break
                }
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }
        
        await MainActor.run {
            self.purchasedProductIDs = purchasedProducts
            self.hasUnlockedPro = !purchasedProducts.isEmpty
            savePurchaseState()
        }
    }
    
    // MARK: - Free Tier Management
    func canProcessPhoto() -> Bool {
        // 暂时禁用限制，方便测试
        return true
        
        // 原来的限制逻辑（已暂停）
        // resetDailyCountIfNeeded()
        // return hasUnlockedPro || dailyPhotoCount < freePhotoLimit
    }
    
    func incrementPhotoCount() {
        guard !hasUnlockedPro else { return }
        resetDailyCountIfNeeded()
        dailyPhotoCount += 1
        saveDailyUsage()
    }
    
    func getRemainingFreePhotos() -> Int {
        guard !hasUnlockedPro else { return Int.max }
        resetDailyCountIfNeeded()
        return max(0, freePhotoLimit - dailyPhotoCount)
    }
    
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyPhotoCount = 0
            lastResetDate = Date()
            saveDailyUsage()
        }
    }
    
    // MARK: - Persistence
    private func savePurchaseState() {
        UserDefaults.standard.set(hasUnlockedPro, forKey: "hasUnlockedPro")
        UserDefaults.standard.set(Array(purchasedProductIDs), forKey: "purchasedProductIDs")
    }
    
    private func loadPurchaseState() {
        hasUnlockedPro = UserDefaults.standard.bool(forKey: "hasUnlockedPro")
        let productIDs = UserDefaults.standard.array(forKey: "purchasedProductIDs") as? [String] ?? []
        purchasedProductIDs = Set(productIDs)
    }
    
    private func saveDailyUsage() {
        UserDefaults.standard.set(dailyPhotoCount, forKey: "dailyPhotoCount")
        UserDefaults.standard.set(lastResetDate, forKey: "lastResetDate")
    }
    
    private func loadDailyUsage() {
        dailyPhotoCount = UserDefaults.standard.integer(forKey: "dailyPhotoCount")
        lastResetDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date ?? Date()
    }
}

// MARK: - Store Errors
enum StoreError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        }
    }
}
