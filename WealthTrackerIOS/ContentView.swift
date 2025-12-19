import SwiftUI

struct ContentView: View {
    @StateObject private var investmentsViewModel = InvestmentsViewModel()
    
    var body: some View {
        TabView {
            DashboardView()
                .environmentObject(investmentsViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            
            InvestmentsView()
                .environmentObject(investmentsViewModel)
                .tabItem {
                    Label("Portfolio", systemImage: "briefcase.fill")
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
