import SwiftUI
import Photos

struct FullScreenPhotoView: View {
    let image: UIImage
    let photo: Photo
    @Environment(\.presentationMode) var presentationMode
    @State private var isControlsVisible = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isControlsVisible.toggle()
                    }
                    
                    if isControlsVisible {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                isControlsVisible = false
                            }
                        }
                    }
                }
            
            if isControlsVisible {
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.telkaBold(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(photo.formattedDate)
                            .font(.telkaMedium(size: 16))
                            .foregroundColor(.white)
                        
                        Text(photo.formattedLocation)
                            .font(.telkaMedium(size: 16))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.7), .black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // 3秒后自动隐藏控制UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isControlsVisible = false
                }
            }
        }
    }
} 