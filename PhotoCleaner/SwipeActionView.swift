import SwiftUI

enum SwipeActionType {
    case keep
    case archive
    
    var image: String {
        switch self {
        case .keep:
            return "hand.thumbsup.fill"
        case .archive:
            return "trash.fill"
        }
    }
    
    var text: String {
        switch self {
        case .keep:
            return "Keep"
        case .archive:
            return "Archive"
        }
    }
    
    var color: Color {
        switch self {
        case .keep:
            return .green
        case .archive:
            return .red
        }
    }
}

struct SwipeActionView: View {
    var actionType: SwipeActionType
    var opacity: CGFloat
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: actionType.image)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(actionType.color)
            
            Text(actionType.text)
                .font(.telkaBold(size: 36))
                .foregroundColor(actionType.color)
        }
        .opacity(opacity)
        .padding(.horizontal, 10)
    }
}

struct SwipeActionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            HStack(spacing: 100) {
                SwipeActionView(actionType: .archive, opacity: 1.0)
                SwipeActionView(actionType: .keep, opacity: 1.0)
            }
        }
    }
} 