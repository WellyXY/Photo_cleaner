import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showClearAllDataConfirmation = false
    @State private var isProcessing = false
    @State private var showingSubscriptionManagement = false
    
    var body: some View {
        NavigationView {
            List {
                // Subscription Section - 暂时隐藏会员功能
                /*
                Section {
                    Button(action: {
                        showingSubscriptionManagement = true
                    }) {
                        HStack {
                            Image(systemName: purchaseManager.hasUnlockedPro ? "crown.fill" : "crown")
                                .frame(width: 30)
                                .foregroundColor(purchaseManager.hasUnlockedPro ? .yellow : .blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(purchaseManager.hasUnlockedPro ? "Pro Member" : "Free Plan")
                                    .font(.telkaHeadline)
                                    .foregroundColor(.primary)
                                
                                if !purchaseManager.hasUnlockedPro {
                                    Text("\(purchaseManager.getRemainingFreePhotos()) photos remaining today")
                                        .font(.telkaCaption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if !purchaseManager.hasUnlockedPro {
                                Text("Upgrade")
                                    .font(.telkaSubheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.telkaCaption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("Subscription")
                }
                */
                
                Section {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .frame(width: 30)
                            .foregroundColor(.blue)
                        Text("Photo Management")
                    }
                    
                    Toggle("Auto-delete cleaned photos", isOn: .constant(false))
                        .disabled(true)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showClearAllDataConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Data")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Photo Settings")
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .frame(width: 30)
                            .foregroundColor(.blue)
                        Text("About")
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.telkaRegular(size: 14))
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Text("Terms of Use")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.telkaRegular(size: 14))
                        }
                    }
                } header: {
                    Text("App Information")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showClearAllDataConfirmation) {
                Alert(
                    title: Text("Confirm Clear All Data"),
                    message: Text("This action will clear all saved and deleted photo records. This will not delete any photos from your photo library. Do you want to continue?"),
                    primaryButton: .destructive(Text("Clear Data")) {
                        clearAllData()
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
            .overlay(
                isProcessing ? 
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing...")
                                .foregroundColor(.white)
                        }
                        .padding(20)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 10)
                    } : nil
            )
        }
        .sheet(isPresented: $showingSubscriptionManagement) {
            SubscriptionManagementView()
        }
    }
    
    private func clearAllData() {
        isProcessing = true
        
        // 模拟处理时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 清除所有数据
            photoManager.savedPhotos.removeAll()
            photoManager.deletedPhotos.removeAll()
            photoManager.savePhotoLists()
            
            isProcessing = false
            presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(PhotoManager())
} 