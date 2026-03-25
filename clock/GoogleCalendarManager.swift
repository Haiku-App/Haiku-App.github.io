import Foundation
internal import Combine
import SwiftUI
import GoogleSignIn

// Ensure your GoogleSignIn dependency is available.

class GoogleCalendarManager: ObservableObject {
    static let shared = GoogleCalendarManager()
    
    @Published var isSignedIn: Bool = false
    @Published var eventsDidChange: Bool = false

    private let calendarEndpoint = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    private let calendarScope = "https://www.googleapis.com/auth/calendar.events"
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            DispatchQueue.main.async {
                self.updateSignInStatus(user: user)
            }
        }
    }
    
    private func updateSignInStatus(user: GIDGoogleUser?) {
        guard let user = user else {
            self.isSignedIn = false
            return
        }
        
        // Check if the user has granted the calendar scope
        let grantedScopes = user.grantedScopes ?? []
        // Use a more robust check for scopes (ignoring case/trailing slashes)
        let hasScope = grantedScopes.contains { $0.lowercased().hasPrefix(calendarScope.lowercased()) }
        
        self.isSignedIn = hasScope
        
        if hasScope {
            print("Google Sign-In: User is signed in with required scopes.")
            AnalyticsManager.shared.capture("google_calendar_connected")
            self.eventsDidChange.toggle()
        } else {
            print("Google Sign-In: User is signed in but missing calendar scope.")
        }
    }
    
    func signIn(presenting viewController: UIViewController) {
        let scopes = [calendarScope]
        
        print("Google Sign-In: Starting sign-in flow...")
        
        // If we already have a user but missing scopes, use addScopes
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            print("Google Sign-In: User already signed in, adding scopes...")
            currentUser.addScopes(scopes, presenting: viewController) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Google Add Scopes Error: \(error.localizedDescription)")
                        // If addScopes fails, try a fresh sign-in
                        self.freshSignIn(presenting: viewController, scopes: scopes)
                        return
                    }
                    self.updateSignInStatus(user: result?.user)
                }
            }
        } else {
            freshSignIn(presenting: viewController, scopes: scopes)
        }
    }
    
    private func freshSignIn(presenting viewController: UIViewController, scopes: [String]) {
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController, hint: nil, additionalScopes: scopes) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Google Sign-In Error: \(error.localizedDescription)")
                    self.isSignedIn = false
                    return
                }
                print("Google Sign-In Success.")
                self.updateSignInStatus(user: result?.user)
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        DispatchQueue.main.async {
            self.isSignedIn = false
        }
    }
    
    private func getValidToken(completion: @escaping (String?) -> Void) {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            completion(nil)
            return
        }
        
        user.refreshTokensIfNeeded { user, error in
            if let error = error {
                print("Failed to refresh token: \(error)")
                completion(nil)
                return
            }
            completion(user?.accessToken.tokenString)
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date, theme: AppTheme, completion: @escaping ([Date: [ClockTask]]) -> Void) {
        guard isSignedIn else {
            completion([:])
            return
        }
        
        getValidToken { token in
            guard let token = token else {
                completion([:])
                return
            }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            
            let timeMin = formatter.string(from: startDate)
            let timeMax = formatter.string(from: endDate)
            
            guard var components = URLComponents(string: self.calendarEndpoint) else { return }
            components.queryItems = [
                URLQueryItem(name: "timeMin", value: timeMin),
                URLQueryItem(name: "timeMax", value: timeMax),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime")
            ]
            
            guard let url = components.url else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Google API Network Error: \(error.localizedDescription)")
                    completion([:])
                    return
                }
                
                guard let data = data else {
                    print("Google API Error: No data received")
                    completion([:])
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let items = json["items"] as? [[String: Any]] {
                        
                        let cal = Calendar.current
                        var result: [Date: [ClockTask]] = [:]
                        
                        for (index, item) in items.enumerated() {
                            guard let id = item["id"] as? String,
                                  let startObj = item["start"] as? [String: Any],
                                  let endObj = item["end"] as? [String: Any],
                                  let startStr = startObj["dateTime"] as? String,
                                  let endStr = endObj["dateTime"] as? String else {
                                continue
                            }
                            
                            let title = item["summary"] as? String ?? "Google Event"
                            
                            guard let sDate = formatter.date(from: startStr),
                                  let eDate = formatter.date(from: endStr) else { continue }
                            
                            let eventDate = cal.startOfDay(for: sDate)
                            let sComps = cal.dateComponents([.hour, .minute], from: sDate)
                            let eComps = cal.dateComponents([.hour, .minute], from: eDate)
                            
                            let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
                            var eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
                            
                            let days = cal.dateComponents([.day], from: cal.startOfDay(for: sDate), to: cal.startOfDay(for: eDate)).day ?? 0
                            if days > 0 { eMin += days * 1440 }
                            if eMin <= sMin { eMin = sMin + 60 }
                            
                            let color = aestheticColors[index % aestheticColors.count].color
                            
                            let task = ClockTask(
                                title: title,
                                startMinutes: sMin,
                                endMinutes: eMin,
                                color: color,
                                url: URL(string: item["htmlLink"] as? String ?? ""),
                                externalEventId: "google_" + id
                            )
                            result[eventDate, default: []].append(task)
                        }
                        
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    } else {
                        completion([:])
                    }
                } catch {
                    print("Error parsing google events: \(error)")
                    completion([:])
                }
            }.resume()
        }
    }

    func fetchEvents(for date: Date, theme: AppTheme, completion: @escaping ([ClockTask]) -> Void) {
        guard isSignedIn else {
            completion([])
            return
        }
        
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            completion([])
            return
        }
        
        getValidToken { token in
            guard let token = token else {
                completion([])
                return
            }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            
            let timeMin = formatter.string(from: startOfDay)
            let timeMax = formatter.string(from: endOfDay)
            
            guard var components = URLComponents(string: self.calendarEndpoint) else { return }
            components.queryItems = [
                URLQueryItem(name: "timeMin", value: timeMin),
                URLQueryItem(name: "timeMax", value: timeMax),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime")
            ]
            
            guard let url = components.url else { return }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Google API Network Error: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let data = data else {
                    print("Google API Error: No data received")
                    completion([])
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "no body"
                    print("Google API Error: HTTP \(httpResponse.statusCode). Body: \(body)")
                    completion([])
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let items = json["items"] as? [[String: Any]] {
                        
                        print("Google API Success: Fetched \(items.count) items")
                        var tasks: [ClockTask] = []
                        for (index, item) in items.enumerated() {
                            guard let id = item["id"] as? String,
                                  let startObj = item["start"] as? [String: Any],
                                  let endObj = item["end"] as? [String: Any],
                                  let startStr = startObj["dateTime"] as? String,
                                  let endStr = endObj["dateTime"] as? String else {
                                continue // Ignore all-day events or malformed
                            }
                            
                            let title = item["summary"] as? String ?? "Google Event"
                            
                            guard let startDate = formatter.date(from: startStr),
                                  let endDate = formatter.date(from: endStr) else { continue }
                            
                            let sComps = cal.dateComponents([.hour, .minute], from: startDate)
                            let eComps = cal.dateComponents([.hour, .minute], from: endDate)
                            
                            let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
                            var eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
                            
                            let days = cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: endDate)).day ?? 0
                            if days > 0 { eMin += days * 1440 }
                            if eMin <= sMin { eMin = sMin + 60 }
                            
                            let meetingUrlStr = item["htmlLink"] as? String
                            var meetingUrl = meetingUrlStr != nil ? URL(string: meetingUrlStr!) : nil
                            
                            if let location = item["location"] as? String, location.hasPrefix("http") {
                                meetingUrl = URL(string: location)
                            }
                            
                            // Use aesthetic colors to match the app's theme
                            let color = aestheticColors[index % aestheticColors.count].color
                            
                            let task = ClockTask(
                                title: title,
                                startMinutes: sMin,
                                endMinutes: eMin,
                                color: color,
                                url: meetingUrl,
                                externalEventId: "google_" + id // prefix to differentiate from EKEvent
                            )
                            tasks.append(task)
                        }
                        
                        DispatchQueue.main.async {
                            completion(tasks)
                        }
                    } else {
                        completion([])
                    }
                } catch {
                    print("Error parsing google events: \(error)")
                    completion([])
                }
            }.resume()
        }
    }
    
    // Convert minutes back to RFC3339 for Google
    private func createGoogleDateTimeDict(minutes: Int, on date: Date) -> [String: String]? {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        guard let fullDate = cal.date(from: comps) else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return ["dateTime": formatter.string(from: fullDate)]
    }

    func saveTask(_ task: ClockTask, date: Date, completion: @escaping (String?) -> Void) {
        guard isSignedIn else { completion(nil); return }
        
        getValidToken { token in
            guard let token = token, let url = URL(string: self.calendarEndpoint) else {
                completion(nil)
                return
            }
            
            var safeEndMinutes = task.endMinutes
            if safeEndMinutes <= task.startMinutes { safeEndMinutes += 1440 }
            
            guard let startDict = self.createGoogleDateTimeDict(minutes: task.startMinutes, on: date),
                  let endDict = self.createGoogleDateTimeDict(minutes: safeEndMinutes, on: date) else {
                completion(nil)
                return
            }
            
            let body: [String: Any] = [
                "summary": task.title,
                "start": startDict,
                "end": endDict
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String {
                    completion("google_" + id)
                } else {
                    completion(nil)
                }
            }.resume()
        }
    }
    
    func updateTask(_ task: ClockTask, date: Date) {
        guard isSignedIn, let externalId = task.externalEventId, externalId.hasPrefix("google_") else { return }
        let googleId = externalId.replacingOccurrences(of: "google_", with: "")
        
        getValidToken { token in
            guard let token = token, let url = URL(string: "\(self.calendarEndpoint)/\(googleId)") else { return }
            
            var safeEndMinutes = task.endMinutes
            if safeEndMinutes <= task.startMinutes { safeEndMinutes += 1440 }
            
            guard let startDict = self.createGoogleDateTimeDict(minutes: task.startMinutes, on: date),
                  let endDict = self.createGoogleDateTimeDict(minutes: safeEndMinutes, on: date) else { return }
            
            let body: [String: Any] = [
                "summary": task.title,
                "start": startDict,
                "end": endDict
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request).resume()
        }
    }
    
    func deleteTask(externalId: String) {
        guard isSignedIn, externalId.hasPrefix("google_") else { return }
        let googleId = externalId.replacingOccurrences(of: "google_", with: "")
        
        getValidToken { token in
            guard let token = token, let url = URL(string: "\(self.calendarEndpoint)/\(googleId)") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request).resume()
        }
    }
}
