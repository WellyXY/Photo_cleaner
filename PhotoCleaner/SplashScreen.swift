import SwiftUI

struct SplashScreen: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    var body: some View {
        if isActive {
            ContentView()
                .environmentObject(photoManager)
        } else {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                VStack {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.stack.fill")
                            .font(.telkaRegular(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("PhotoCleaner")
                            .font(.telkaBold(size: 42))
                            .foregroundColor(.black.opacity(0.8))

                        Text("Organize your photo library")
                            .font(.telkaRegular(size: 20))
                            .foregroundColor(.gray)
                    }
                    .scaleEffect(size)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.2)) {
                            self.size = 0.9
                            self.opacity = 1.0
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
} 