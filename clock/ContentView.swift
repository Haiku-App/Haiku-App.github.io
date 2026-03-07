//
//  ContentView.swift
//  clock
//
//  Created by Reswin Kandathil on 3/7/26.
//

import SwiftUI
import Combine

struct ContentView: View {
    // Sample tasks for demo
    @State private var tasks: [ClockTask] = [
        ClockTask(title: "Standup", startMinutes: 9*60 + 0, endMinutes: 9*60 + 30, color: .blue),
        ClockTask(title: "Design Review", startMinutes: 10*60 + 15, endMinutes: 11*60, color: .pink),
        ClockTask(title: "Lunch", startMinutes: 12*60, endMinutes: 13*60, color: .green),
        ClockTask(title: "1:1", startMinutes: 14*60, endMinutes: 14*60 + 30, color: .orange),
        ClockTask(title: "Focus", startMinutes: 15*60, endMinutes: 16*60 + 30, color: .purple)
    ]

    // Update every 30s to keep the hand current
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ClockView(tasks: tasks, now: now)
                    .frame(width: 320, height: 320)
                    .padding(.top, 16)

                // Simple legend/list
                List(tasks) { task in
                    HStack(spacing: 12) {
                        Circle().fill(task.color).frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(task.title).font(.body)
                            Text("\(formatTime(task.startMinutes)) – \(formatTime(task.endMinutes))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Clock Agenda")
        }
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

