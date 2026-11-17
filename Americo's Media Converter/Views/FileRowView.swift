import SwiftUI

struct FileRowView: View {
    let file: MediaFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.hasVideo ? "video" : "hifispeaker")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(red: 0.1, green: 1, blue: 0.1).opacity(0.5))
                .frame(width: 40, height: 40)
                .accessibilityLabel(file.hasVideo ? "Video file" : "Audio file")

            VStack(alignment: .leading, spacing: 1) {
                Text(file.title)
                    .font(.system(size: 13))
                    .bold()
                    .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.2).opacity(0.7))
                    .lineLimit(1)
                Text(file.info)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .opacity(file.hasError ? 1 : 0)
                .accessibilityHidden(true)

            ProgressView(value: file.progress, total: 100)
                .tint(file.hasError ? Color(red: 0.9, green: 0.1, blue: 0.1) : Color(red: 0.1, green: 0.9, blue: 0.1))
                .frame(width: 100)
                .opacity(file.isProgressVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: file.progress)
                .accessibilityLabel("Conversion progress")
                .accessibilityValue(file.hasError ? "Failed" : "\(Int(file.progress)) percent")
                .accessibilityHidden(!file.isProgressVisible)
        }
        .padding(.trailing, 10)
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
