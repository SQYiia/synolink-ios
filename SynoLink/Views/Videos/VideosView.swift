import SwiftUI

struct VideosView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("视频功能开发中", systemImage: "video", description: Text("即将推出"))
                .navigationTitle("视频")
        }
    }
}
