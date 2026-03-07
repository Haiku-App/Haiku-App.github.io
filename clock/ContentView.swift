import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var tasks: [ClockTask] = [
        ClockTask(title: "Matcha Tasting", startMinutes: 14*60, endMinutes: 15*60, color: Color(red: 0.85, green: 0.78, blue: 0.58)), // 2:00 PM - 3:00 PM
        ClockTask(title: "Garden Walk", startMinutes: 16*60, endMinutes: 17*60 + 30, color: Color(red: 0.85, green: 0.78, blue: 0.58)) // 4:00 PM - 5:30 PM
    ]

    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("HAIKU")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(goldColor)
                        .tracking(2)

                    HStack {
                        Spacer()
                        Text("October 2023") // Using the date from image
                            .font(.system(size: 14, weight: .light, design: .serif))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.top, 20)

                Spacer()

                // Clock
                ClockView(now: now, tasks: tasks)
                    .frame(width: 280, height: 280)

                Spacer()

                // Task List
                VStack(alignment: .leading, spacing: 28) {
                    TaskRow(time: "2:00 PM", title: "Matcha Tasting")
                    TaskRow(time: "4:00 PM", title: "Garden Walk")
                }
                .padding(.horizontal, 40)
                
                Spacer()

                // Bottom Tab Bar
                HStack {
                    TabBarItem(icon: "clock.fill", text: "Clock", isSelected: true)
                    Spacer()
                    TabBarItem(icon: "calendar", text: "Week", isSelected: false)
                    Spacer()
                    TabBarItem(icon: "calendar.day.timeline.left", text: "Today", isSelected: false)
                    Spacer()
                    TabBarItem(icon: "person.fill", text: "Profile", isSelected: false)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .onReceive(timer) { date in
            now = date
        }
    }
}

struct TaskRow: View {
    var time: String
    var title: String
    var body: some View {
        HStack(spacing: 16) {
            Text(time)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)
            
            // Vertical separator
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 16)
            
            // Leaf icon
            Image(systemName: "leaf")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
    }
}

struct TabBarItem: View {
    var icon: String
    var text: String
    var isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
        }
    }
}

#Preview {
    ContentView()
}
