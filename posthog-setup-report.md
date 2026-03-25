<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into the Haiku iOS app (SwiftUI). Here is a summary of all changes made:

- **`clock.xcodeproj/project.pbxproj`** — Added the PostHog iOS SDK (`posthog-ios` v3.48.0) as a Swift Package Manager dependency with three UUID objects: a `PBXBuildFile`, an `XCSwiftPackageProductDependency`, and an `XCRemoteSwiftPackageReference`.
- **`clock.xcodeproj/xcshareddata/xcschemes/clock.xcscheme`** — Added `POSTHOG_PROJECT_TOKEN` and `POSTHOG_HOST` as Xcode scheme Run environment variables so the app can read them at runtime without hardcoding.
- **`.env`** — Created with the PostHog credentials for reference.
- **`clock/clockApp.swift`** — Added `import PostHog`, a `PostHogEnv` enum to read credentials from environment variables, and SDK initialization with `captureApplicationLifecycleEvents = true`.
- **`clock/OnboardingView.swift`** — Added `onboarding_completed` and `onboarding_skipped` capture calls.
- **`clock/AddTaskView.swift`** — Added `task_created` and `task_updated` capture calls with duration and metadata properties.
- **`clock/ContentView.swift`** — Added `task_deleted` capture call on swipe-delete.
- **`clock/HaikuProView.swift`** — Added `paywall_viewed` (on appear) and `purchase_initiated` (with package details) capture calls.
- **`clock/StoreManager.swift`** — Added `purchase_completed` (when Pro entitlement becomes active) and `purchase_restored` capture calls.
- **`clock/GoogleCalendarManager.swift`** — Added `google_calendar_connected` capture call when calendar scope is granted.
- **`clock/TodoView.swift`** — Added `brain_dump_task_added` and `brain_dump_task_scheduled` capture calls.

## Events instrumented

| Event | Description | File |
|---|---|---|
| `onboarding_completed` | User taps 'Get Started' on the final onboarding step | `clock/OnboardingView.swift` |
| `onboarding_skipped` | User taps 'Skip' to bypass onboarding | `clock/OnboardingView.swift` |
| `task_created` | User adds a new task to the schedule | `clock/AddTaskView.swift` |
| `task_updated` | User edits and saves an existing task | `clock/AddTaskView.swift` |
| `task_deleted` | User swipe-deletes a task from the clock view | `clock/ContentView.swift` |
| `paywall_viewed` | User views the Haiku Pro paywall/upgrade screen | `clock/HaikuProView.swift` |
| `purchase_initiated` | User taps a pricing button to begin a Pro purchase | `clock/HaikuProView.swift` |
| `purchase_completed` | User's Pro entitlement becomes active after a successful purchase | `clock/StoreManager.swift` |
| `purchase_restored` | User restores previous Pro purchases | `clock/StoreManager.swift` |
| `google_calendar_connected` | User successfully signs in with Google and grants calendar scope | `clock/GoogleCalendarManager.swift` |
| `brain_dump_task_added` | User adds a quick task to the Brain Dump list | `clock/TodoView.swift` |
| `brain_dump_task_scheduled` | User schedules a Brain Dump task to a specific date/time on the clock | `clock/TodoView.swift` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- **Dashboard — Analytics basics**: https://us.posthog.com/project/354135/dashboard/1391238
- **Pro Purchase Conversion Funnel** (paywall → initiated → completed): https://us.posthog.com/project/354135/insights/wY7AZLEI
- **Daily Task Activity** (created vs deleted): https://us.posthog.com/project/354135/insights/6WcupMEb
- **Onboarding Completion vs Skip**: https://us.posthog.com/project/354135/insights/zB2NwJlF
- **Weekly Task Creator Retention**: https://us.posthog.com/project/354135/insights/3J0c7NTP
- **Brain Dump: Add vs Schedule Rate**: https://us.posthog.com/project/354135/insights/B304Pzg0

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-swift/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
