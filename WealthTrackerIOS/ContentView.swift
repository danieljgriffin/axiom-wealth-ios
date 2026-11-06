import SwiftUI

struct ContentView: View {
    @StateObject private var investmentsViewModel = InvestmentsViewModel()
    @State private var trackerRevision = 0
    
    var body: some View {
        TabView {
            DashboardView(trackerRevision: trackerRevision)
                .environmentObject(investmentsViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            InvestmentsView()
                .environmentObject(investmentsViewModel)
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
                }

            TrackerView(onSave: { trackerRevision += 1 })
                .environmentObject(investmentsViewModel)
                .tabItem {
                    Label("Tracker", systemImage: "calendar")
                }
        }
        .task {
            await investmentsViewModel.loadData()
        }
    }
}

#Preview {
    ContentView()
}
