import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.currentProject == nil {
                ProjectListView()
            } else {
                EditorWorkspaceView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await appState.workspaceManager.refreshProjects()
        }
    }
}
