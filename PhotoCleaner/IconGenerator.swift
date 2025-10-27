import SwiftUI

struct AppIcon: View {
    // App icon dimensions in points
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.9),
                    Color(red: 0.0, green: 0.6, blue: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(size * 0.22)
            
            // Icon foreground elements
            VStack(spacing: 0) {
                // Top photo element
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.07)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: size * 0.45, height: size * 0.35)
                        .shadow(color: Color.black.opacity(0.2), radius: size * 0.02, x: 0, y: size * 0.01)
                    
                    // Simulated landscape photo
                    Image(systemName: "mountain.2.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blue)
                        .frame(width: size * 0.28, height: size * 0.20)
                }
                .offset(x: -size * 0.12, y: -size * 0.05)
                .rotated(-8)
                
                // Middle photo element
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.07)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: size * 0.5, height: size * 0.38)
                        .shadow(color: Color.black.opacity(0.2), radius: size * 0.02, x: 0, y: size * 0.01)
                    
                    // Simulated portrait photo
                    Image(systemName: "person.crop.rectangle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.indigo)
                        .frame(width: size * 0.3, height: size * 0.22)
                }
                .offset(y: -size * 0.07)
                .rotated(5)
                
                // Bottom photo element
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.07)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: size * 0.45, height: size * 0.35)
                        .shadow(color: Color.black.opacity(0.2), radius: size * 0.02, x: 0, y: size * 0.01)
                    
                    // Simulated nature photo
                    Image(systemName: "leaf.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.green)
                        .frame(width: size * 0.25, height: size * 0.20)
                }
                .offset(x: size * 0.15, y: -size * 0.12)
                .rotated(10)
            }
            
            // Clean overlay element
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.orange]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.25, height: size * 0.25)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.telkaBold(size: size * 0.14))
                        .foregroundColor(.white)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                .offset(x: size * 0.25, y: size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

struct IconGenerator: View {
    // Different size examples
    var body: some View {
        VStack(spacing: 40) {
            AppIcon(size: 200)
                .shadow(radius: 10)
            
            Text("PhotoCleaner Icon")
                .font(.telkaTitle2)
                .fontWeight(.medium)
            
            HStack(spacing: 20) {
                VStack {
                    AppIcon(size: 60)
                    Text("iPhone")
                        .font(.telkaCaption)
                }
                
                VStack {
                    AppIcon(size: 40)
                    Text("Settings")
                        .font(.telkaCaption)
                }
                
                VStack {
                    AppIcon(size: 30)
                    Text("Spotlight")
                        .font(.telkaCaption)
                }
            }
        }
        .padding()
    }
}

// Helper extension for rotation
extension View {
    func rotated(_ degrees: Double) -> some View {
        self.rotationEffect(Angle(degrees: degrees))
    }
}

#Preview {
    IconGenerator()
} 