import SwiftUI

struct ImageResourceDebugView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("图片资源测试")
                .font(.title)
            
            Divider()
            
            Group {
                Text("Like 图标:").font(.headline)
                Image("Like")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .border(Color.gray)
                
                Text("Dislike 图标:").font(.headline)
                Image("Dislike")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .border(Color.gray)
            }
            
            Divider()
            
            Group {
                Text("测试 SwipeActionView:").font(.headline)
                
                HStack(spacing: 40) {
                    SwipeActionView(actionType: .archive, opacity: 1.0)
                        .border(Color.gray)
                    
                    SwipeActionView(actionType: .keep, opacity: 1.0)
                        .border(Color.gray)
                }
            }
            
            Divider()
            
            // 添加系统图标作为对比
            Group {
                Text("系统图标测试:").font(.headline)
                
                HStack(spacing: 40) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.red)
                    
                    Image(systemName: "hand.thumbsup.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
}

struct ImageResourceDebugView_Previews: PreviewProvider {
    static var previews: some View {
        ImageResourceDebugView()
    }
} 