import SwiftUI

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            isPressed = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.telkaMedium(size: 26))
                .foregroundColor(.white)
                .padding(22)
                .background(
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.8))
                        
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .blur(radius: isPressed ? 4 : 0)
                    }
                )
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct CustomActionButton: View {
    let imageName: String
    let backgroundColor: Color
    let size: CGFloat
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景圆圈
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: backgroundColor.opacity(0.5), radius: 10, x: 0, y: 5)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                // 自定义图像
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.6, height: size * 0.6)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in self.isPressed = true }
                    .onEnded { _ in self.isPressed = false }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
} 