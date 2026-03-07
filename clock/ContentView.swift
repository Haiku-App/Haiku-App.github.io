//
//  ContentView.swift
//  clock
//
//  Created by Reswin Kandathil on 3/7/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    // Sample tasks matching the image's aesthetic
    @State private var tasks: [ClockTask] = [
        ClockTask(title: "Focus", startMinutes: 13*60, endMinutes: 14*60, color: Color(red: 0.36, green: 0.61, blue: 0.84))
    ]

    // Update frequently for smooth second hand sweep
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                    // Dark green background
                Color(red: 0.05, green: 0.15, blue: 0.08).ignoresSafeArea()
                
                VStack(spacing: 32) {
                    ClockView(tasks: tasks, now: now)
                        .frame(width: 320, height: 320)
                        .padding(.top, 32)

                    // Simple legend/list
                    List(tasks) { task in
                        HStack(spacing: 12) {
                            Circle().fill(task.color).frame(width: 12, height: 12)
                            VStack(alignment: .leading) {
                                Text(task.title)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                Text("\(formatTime(task.startMinutes)) – \(formatTime(task.endMinutes))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                }
            }
            .navigationTitle("Clock Agenda")
            .toolbarBackground(Color(red: 0.05, green: 0.15, blue: 0.08), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark) // Force dark mode
        .onReceive(timer) { date in
            now = date
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        let m = minutes % (24*60)
        let h = m / 60
        let min = m % 60
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var comps = DateComponents()
        comps.hour = h
        comps.minute = min
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
