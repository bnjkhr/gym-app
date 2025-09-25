import SwiftUI

struct ProfileImageView: View {
    let image: UIImage?
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    colorScheme == .dark 
                    ? Color.white.opacity(0.1) 
                    : Color.black.opacity(0.1), 
                    lineWidth: 1
                )
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), 
            radius: 8, 
            x: 0, 
            y: 4
        )
    }
}

#Preview {
    ProfileImageView(image: nil, size: 100)
        .padding()
}