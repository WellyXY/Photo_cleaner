import SwiftUI

struct LimitReachedView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingPaywall = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.telkaRegular(size: 60))
                .foregroundColor(.orange)
            
            // Title and Message
            VStack(spacing: 12) {
                Text("Daily Limit Reached")
                    .font(.telkaTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("You've processed 10 photos today. Upgrade to Pro for unlimited photo processing and premium features.")
                    .font(.telkaBody)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Features Preview
            VStack(alignment: .leading, spacing: 12) {
                Text("Pro Features:")
                    .font(.telkaHeadline)
                
                ForEach([
                    "Unlimited photo processing",
                    "Advanced AI sorting",
                    "Batch operations",
                    "Priority support"
                ], id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(feature)
                            .font(.telkaSubheadline)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    showingPaywall = true
                }) {
                    Text("Upgrade to Pro")
                        .font(.telkaHeadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Maybe Later")
                        .font(.telkaSubheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    LimitReachedView()
}

