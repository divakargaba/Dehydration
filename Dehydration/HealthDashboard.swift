import SwiftUI
import HealthKit
import CoreMotion
import UIKit
import UserNotifications
import WidgetKit
import ActivityKit

struct HealthMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - New Feature Models

struct CoachSuggestion: Identifiable, Codable {
    let id = UUID()
    let title: String
    let message: String
    let level: FeedbackLevel
    let reason: String
    let quickActions: [QuickAction]
    let timestamp: Date
    
    enum FeedbackLevel: String, Codable, CaseIterable {
        case info = "info"
        case warning = "warning"
        case critical = "critical"
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.octagon.fill"
            }
        }
    }
}

struct QuickAction: Identifiable, Codable {
    let id = UUID()
    let title: String
    let amount: Int // ml for water
    let type: ActionType
    
    enum ActionType: String, Codable {
        case logWater = "log_water"
        case setReminder = "set_reminder"
    }
}

struct RiskPrediction: Codable {
    let eta: String
    let confidence: Double
    let factors: [RiskFactor]
    let timestamp: Date
}

struct RiskFactor: Identifiable, Codable {
    let id = UUID()
    let name: String
    let impact: Double // 0-1
    let description: String
}

struct HydrationStreak: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastLogDate: Date?
    let dailyGoal: Double // liters
    var todayProgress: Double
}

struct InsightCard: Identifiable, Codable {
    let id = UUID()
    let title: String
    let subtitle: String
    let value: String
    let trend: TrendDirection
    let category: InsightCategory
    let details: String
    
    enum TrendDirection: String, Codable {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.circle.fill"
            case .down: return "arrow.down.circle.fill"
            case .stable: return "minus.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
    
    enum InsightCategory: String, Codable, CaseIterable {
        case hydration, activity, weather, health
        
        var icon: String {
            switch self {
            case .hydration: return "drop.fill"
            case .activity: return "figure.walk"
            case .weather: return "cloud.sun.fill"
            case .health: return "heart.fill"
            }
        }
    }
}

struct AppTheme: Codable {
    let name: String
    let primaryColor: String
    let secondaryColor: String
    let backgroundColor: String
    let isOLED: Bool
    
    static let themes = [
        AppTheme(name: "Professional Dark", primaryColor: "indigo", secondaryColor: "blue", backgroundColor: "black", isOLED: true),
        AppTheme(name: "Modern Blue", primaryColor: "blue", secondaryColor: "cyan", backgroundColor: "systemBackground", isOLED: false),
        AppTheme(name: "Sport", primaryColor: "orange", secondaryColor: "red", backgroundColor: "systemBackground", isOLED: false)
    ]
}

struct QueuedMetric: Codable {
    let id: UUID
    let payload: [String: Any]
    let timestamp: Date
    let endpoint: String
    
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, endpoint, payloadData
    }
    
    init(payload: [String: Any], endpoint: String) {
        self.id = UUID()
        self.payload = payload
        self.timestamp = Date()
        self.endpoint = endpoint
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.endpoint = try container.decode(String.self, forKey: .endpoint)
        let payloadData = try container.decode(Data.self, forKey: .payloadData)
        self.payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(endpoint, forKey: .endpoint)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)
        try container.encode(payloadData, forKey: .payloadData)
    }
}

struct ReminderSettings: Codable {
    var isEnabled: Bool = true
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
    var intervalMinutes: Int = 60
    var contextAware: Bool = true
    var lastReminderTime: Date?
    var snoozeUntil: Date?
    var effectivenessScore: Double = 0.0 // Track if reminders lead to water logging
}

// MARK: - New Feature UI Components

private struct CoachCard: View {
    let suggestion: CoachSuggestion
    let onQuickAction: (QuickAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.level.icon)
                    .foregroundColor(suggestion.level.color)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(suggestion.level.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(suggestion.level.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(suggestion.level.color.opacity(0.2))
                        .cornerRadius(8)
                }
                Spacer()
            }
            
            Text(suggestion.message)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if !suggestion.reason.isEmpty {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Why? \(suggestion.reason)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !suggestion.quickActions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(suggestion.quickActions) { action in
                        Button(action: { onQuickAction(action) }) {
                            Text(action.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

private struct RiskETAPanel: View {
    let prediction: RiskPrediction?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Risk Prediction")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let prediction = prediction {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ETA to High Risk:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(prediction.eta)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                    
                    HStack {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(prediction.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    if !prediction.factors.isEmpty {
                        Text("Top Contributing Factors:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        
                        ForEach(prediction.factors.prefix(3)) { factor in
                            HStack {
                                Circle()
                                    .fill(Color.red.opacity(factor.impact))
                                    .frame(width: 8, height: 8)
                                Text(factor.name)
                                    .font(.caption2)
                                Spacer()
                                Text("\(Int(factor.impact * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("Loading prediction...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

private struct StreakCard: View {
    let streak: HydrationStreak
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Hydration Streak")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(streak.currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(streak.longestStreak)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Best")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Today's Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(streak.todayProgress, specifier: "%.1f")/\(streak.dailyGoal, specifier: "%.1f")L")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ProgressView(value: streak.todayProgress, total: streak.dailyGoal)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 60)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

private struct InsightCardView: View {
    let insight: InsightCard
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: insight.category.icon)
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: insight.trend.icon)
                        .foregroundColor(insight.trend.color)
                        .font(.caption)
                }
                
                Text(insight.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Text(insight.value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func showInsightDetails(_ insight: InsightCard) {
        // In a real app, this would show a detailed view
        print("Showing details for: \(insight.title)")
    }
}

private struct QuickLogSheet: View {
    @Binding var isPresented: Bool
    let onLog: (Int) -> Void
    let dailyGoal: Double
    let currentProgress: Double
    
    private let presets = [250, 350, 500, 750]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Progress Section
                VStack(spacing: 12) {
                    Text("Today's Progress")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("\(currentProgress, specifier: "%.1f")L")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("/ \(dailyGoal, specifier: "%.1f")L")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: currentProgress, total: dailyGoal)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(y: 2)
                        
                        let remaining = max(0, dailyGoal - currentProgress)
                        Text("\(remaining, specifier: "%.1f")L remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Quick Log Buttons
                VStack(spacing: 16) {
                    Text("Quick Log")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(presets, id: \.self) { amount in
                            Button(action: {
                                onLog(amount)
                                isPresented = false
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "drop.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text("\(amount)ml")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    isPresented = false
                }
            )
        }
    }
}

private struct ThemeSelector: View {
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Theme")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(AppTheme.themes, id: \.name) { theme in
                Button(action: { selectedTheme = theme }) {
                    HStack {
                        Circle()
                            .fill(colorFromString(theme.primaryColor))
                            .frame(width: 20, height: 20)
                        
                        Text(theme.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        if theme.isOLED {
                            Text("OLED")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        if selectedTheme.name == theme.name {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .blue
        }
    }
}

struct SettingsView: View {
    @Binding var selectedTheme: AppTheme
    @Binding var reminderSettings: ReminderSettings
    @State private var showingThemeSelector = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Button(action: { showingThemeSelector = true }) {
                        HStack {
                            Circle()
                                .fill(colorFromString(selectedTheme.primaryColor))
                                .frame(width: 20, height: 20)
                            Text(selectedTheme.name)
                            Spacer()
                            Text("Theme")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Reminders") {
                    Toggle("Smart Reminders", isOn: $reminderSettings.isEnabled)
                    
                    if reminderSettings.isEnabled {
                        Toggle("Context Aware", isOn: $reminderSettings.contextAware)
                        
                        HStack {
                            Text("Interval")
                            Spacer()
                            Text("\(reminderSettings.intervalMinutes) min")
                                .foregroundColor(.secondary)
                        }
                        
                        DatePicker("Quiet Hours Start", selection: $reminderSettings.quietHoursStart, displayedComponents: .hourAndMinute)
                        DatePicker("Quiet Hours End", selection: $reminderSettings.quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("Data") {
                    HStack {
                        Text("Sync Status")
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.green)
                    }
                    
                    Button("Export Health Data") {
                        // Export functionality
                    }
                    
                    Button("Clear Cache") {
                        // Clear cache functionality
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingThemeSelector) {
                NavigationStack {
                    ThemeSelector(selectedTheme: $selectedTheme)
                        .navigationTitle("Choose Theme")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(
                            trailing: Button("Done") {
                                showingThemeSelector = false
                            }
                        )
                }
            }
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "cyan": return .cyan
        case "indigo": return .indigo
        default: return .blue
        }
    }
}

struct Developer: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let email: String
}





struct WeatherSection: View {
    let weather: WeatherData
    var body: some View {
        HStack {
            Image(systemName: "cloud.sun.fill")
                .foregroundColor(.orange)
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Weather")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(weather.temperature, specifier: "%.1f")°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(weather.description.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Humidity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(weather.humidity)%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct ModelStatusCardView: View {
    let status: ModelStatus
    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.green)
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Personal AI Model")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(status.total_records) data points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Active")
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct ConnectionStatusRow: View {
    let isConnected: Bool
    let lastUpdate: Date
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: isConnected ? Color.green.opacity(0.5) : Color.red.opacity(0.5), radius: 4)
                
                Text(isConnected ? "Connected" : "Offline")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isConnected ? .green : .red)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(lastUpdate, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.6),
                    Color.indigo.opacity(0.05),
                    Color.black.opacity(0.7)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct AlertsSectionView: View {
    let alerts: [Alert]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Alerts")
                .font(.headline)
                .padding(.horizontal)
            ForEach(alerts.prefix(3), id: \.id) { alert in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text(alert.message)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(alert.timestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.2),
                            Color.red.opacity(0.05),
                            Color.red.opacity(0.15)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }
}

struct MetricsGridView: View {
    let metrics: [HealthMetric]
    let steps: Double
    let activeEnergy: Double
    let waterIntake: Double
    let columns: [GridItem]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(metrics) { metric in
                ModernMetricCard(metric: metric)
            }
            ModernMetricCard(metric: HealthMetric(
                title: "Steps",
                value: String(format: "%.0f", steps),
                unit: "",
                color: .green,
                icon: "figure.walk"
            ))
            ModernMetricCard(metric: HealthMetric(
                title: "Active Energy",
                value: String(format: "%.0f", activeEnergy),
                unit: "kcal",
                color: .orange,
                icon: "flame"
            ))
            ModernMetricCard(metric: HealthMetric(
                title: "Water Intake",
                value: String(format: "%.1f", waterIntake),
                unit: "L",
                color: .blue,
                icon: "drop.fill"
            ))
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: steps)
        .animation(.easeInOut(duration: 0.3), value: activeEnergy)
        .animation(.easeInOut(duration: 0.3), value: waterIntake)
    }
}

struct MotionSectionView: View {
    let accX: Double
    let accY: Double
    let accZ: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motion Data")
                .font(.headline)
                .padding(.horizontal)
            HStack(spacing: 12) {
                ModernMetricCard(metric: HealthMetric(
                    title: "Acceleration X",
                    value: String(format: "%.3f", accX),
                    unit: "g",
                    color: .purple,
                    icon: "arrow.left.and.right"
                ))
                ModernMetricCard(metric: HealthMetric(
                    title: "Acceleration Y",
                    value: String(format: "%.3f", accY),
                    unit: "g",
                    color: .purple,
                    icon: "arrow.up.and.down"
                ))
                ModernMetricCard(metric: HealthMetric(
                    title: "Acceleration Z",
                    value: String(format: "%.3f", accZ),
                    unit: "g",
                    color: .purple,
                    icon: "arrow.up.and.down.circle"
                ))
            }
            .padding(.horizontal)
        }
    }
}

struct SendButtonView: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                Text("Send Data")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.indigo.opacity(0.1),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.indigo.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

struct DeveloperCard: View {
    let developer: Developer
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 4) {
                Text(developer.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(developer.role)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(developer.email)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.indigo.opacity(0.1),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.indigo.opacity(0.2), radius: 12, x: 0, y: 6)
    }
}

struct DeveloperView: View {
    let developers = [
        Developer(name: "Divakar Gaba", role: "Lead Developer", email: "divakar.gaba@example.com"),
        Developer(name: "Zehaan Walji", role: "Backend Developer", email: "zehaan.walji@example.com")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Development Team")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Meet the developers behind the Hydration Monitor")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Developers Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 16) {
                    ForEach(developers) { developer in
                        DeveloperCard(developer: developer)
                    }
                }
                .padding(.horizontal)
                
                // Project Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Project Information")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Hydration Monitor v1.0")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.green)
                            Text("Last Updated: July 2025")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.orange)
                            Text("Technology: SwiftUI, HealthKit, Flask, React")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .cornerRadius(4, corners: .topLeft)
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 30, height: 30)
                        
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(18)
                            .cornerRadius(4, corners: .topRight)
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 38)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

struct ChatbotView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var isConnected: Bool = false
    
    // Use Mac's IP address for real device testing
    let serverURL = "http://192.168.1.75:5000"
    
    var body: some View {
        ZStack {
            // Dark background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.95),
                    Color.indigo.opacity(0.1),
                    Color.black.opacity(0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Hydration Assistant")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Connection status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(isConnected ? "Connected" : "Offline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
            }
            .padding(.top)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        
                        if isTyping {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                            .frame(width: 30, height: 30)
                                        
                                        HStack(spacing: 4) {
                                            ForEach(0..<3) { index in
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 6, height: 6)
                                                    .scaleEffect(1.0)
                                                    .animation(
                                                        Animation.easeInOut(duration: 0.6)
                                                            .repeatForever()
                                                            .delay(Double(index) * 0.2),
                                                        value: isTyping
                                                    )
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(18)
                                        .cornerRadius(4, corners: .topRight)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 12) {
                    TextField("Ask about your hydration...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isTyping)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
                }
                .padding()
            }
        }
        .onAppear {
            addWelcomeMessage()
            checkConnection()
        }
        } // Close ZStack
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your hydration assistant. I can analyze your health metrics and provide personalized hydration advice. How can I help you today?",
            isUser: false,
            timestamp: Date()
        )
        self.messages.append(welcomeMessage)
    }
    
    private func checkConnection() {
        guard let url = URL(string: "\(serverURL)/latest_metrics") else { return }
        
        URLSession.shared.dataTask(with: url) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self.isConnected = httpResponse.statusCode == 200
                } else {
                    self.isConnected = false
                }
            }
        }.resume()
    }
    
    private func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(
            content: trimmedText,
            isUser: true,
            timestamp: Date()
        )
        self.messages.append(userMessage)
        self.inputText = ""
        
        // Show typing indicator
        self.isTyping = true
        
        // Send to backend
        sendToBackend(message: trimmedText)
    }
    
    private func sendToBackend(message: String) {
        guard let url = URL(string: "\(serverURL)/api/chat") else {
            handleError("Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["message": message]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            handleError("Failed to encode message")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isTyping = false
                
                if let error = error {
                    self.handleError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.handleError("No response data")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    let botMessage = ChatMessage(
                        content: responseString,
                        isUser: false,
                        timestamp: Date()
                    )
                    self.messages.append(botMessage)
                } else {
                    self.handleError("Failed to decode response")
                }
            }
        }.resume()
    }
    
    private func handleError(_ message: String) {
        let errorMessage = ChatMessage(
            content: "Sorry, I'm having trouble connecting to the server. Please check your connection and try again.",
            isUser: false,
            timestamp: Date()
        )
        self.messages.append(errorMessage)
    }
}

// Extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Professional Loading Animation
struct ProfessionalLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.indigo)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct ModernHeaderCard: View {
    let status: String
    let risk: String
    let reason: String
    let time: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.purple.opacity(0.18), radius: 8, x: 0, y: 4)
                    Image(systemName: risk == "High" ? "exclamationmark.triangle.fill" : (risk == "Moderate" ? "exclamationmark.circle.fill" : "checkmark.seal.fill"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hydration Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(status)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Risk (10–30 min): ")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text(risk)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(risk == "High" ? .red : (risk == "Moderate" ? .yellow : .green))
                        if let t = time {
                            Text(t)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            if !reason.isEmpty {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.indigo.opacity(0.1),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.indigo.opacity(0.3), radius: 16, x: 0, y: 8)
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(.easeInOut, value: risk)
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct ModernMetricCard: View {
    let metric: HealthMetric
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(metric.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: metric.icon)
                    .font(.title2)
                    .foregroundColor(metric.color)
            }
            Text(metric.title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(metric.value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(metric.color)
            if !metric.unit.isEmpty {
                Text(metric.unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    metric.color.opacity(0.1),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: metric.color.opacity(0.2), radius: 10, x: 0, y: 4)
        .animation(.easeInOut, value: metric.value)
        .scaleEffect(metric.value.isEmpty ? 0.95 : 1.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: metric.value)
    }
}

struct AnalyticsView: View {
    @State private var analytics: AnalyticsData?
    @State private var isLoading = false
    let userId: String
    let serverURL: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading analytics...")
                        .padding()
                } else if let analytics = analytics {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        AnalyticsCard(
                            title: "Total Days",
                            value: "\(analytics.summary.total_days)",
                            icon: "calendar",
                            color: .blue
                        )
                        AnalyticsCard(
                            title: "Total Steps",
                            value: "\(analytics.summary.total_steps)",
                            icon: "figure.walk",
                            color: .green
                        )
                        AnalyticsCard(
                            title: "Water Intake",
                            value: String(format: "%.1fL", analytics.summary.total_water_liters),
                            icon: "drop.fill",
                            color: .blue
                        )
                        AnalyticsCard(
                            title: "Risk %",
                            value: String(format: "%.1f%%", analytics.summary.dehydration_risk_percentage),
                            icon: "exclamationmark.triangle.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal)
                    
                    // Trends Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trends")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("Water Intake Trend")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(analytics.trends.water_intake_trend.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Recent Average")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(analytics.trends.recent_avg_water, specifier: "%.2f")L")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Overall Average")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(analytics.trends.overall_avg_water, specifier: "%.2f")L")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Best/Worst Days
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            VStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                                Text("Best Day")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(analytics.best_day.water_intake, specifier: "%.1f")L")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("\(analytics.best_day.steps) steps")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(12)
                            
                            VStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                Text("Needs Improvement")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(analytics.worst_day.water_intake, specifier: "%.1f")L")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("\(analytics.worst_day.steps) steps")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("No analytics data available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.top)
        }
        .navigationTitle("Analytics")
        .onAppear {
            loadAnalytics()
        }
    }
    
    func loadAnalytics() {
        isLoading = true
        guard let url = URL(string: "\(serverURL)/user/\(userId)/analytics") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Failed to load analytics:", error)
                    return
                }
                guard let data = data,
                      let analytics = try? JSONDecoder().decode(AnalyticsData.self, from: data) else {
                    return
                }
                self.analytics = analytics
            }
        }.resume()
    }
}

struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AchievementsView: View {
    @State private var achievements: [Achievement] = []
    @State private var isLoading = false
    let userId: String
    let serverURL: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading achievements...")
                        .padding()
                } else if !achievements.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack {
                        Image(systemName: "trophy")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        Text("No Achievements Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Keep using the app to earn achievements!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding(.top)
        }
        .navigationTitle("Achievements")
        .onAppear {
            loadAchievements()
        }
    }
    
    func loadAchievements() {
        isLoading = true
        guard let url = URL(string: "\(serverURL)/user/\(userId)/achievements") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Failed to load achievements:", error)
                    return
                }
                guard let data = data,
                      let achievements = try? JSONDecoder().decode([Achievement].self, from: data) else {
                    return
                }
                self.achievements = achievements
            }
        }.resume()
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundColor(.yellow)
            Text(achievement.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            // earned_at is a String; show raw string. If you want formatted date, parse it to Date first
            Text(achievement.earned_at)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InsightsView: View {
    let userId: String
    let serverURL: String
    
    @State private var insights: [InsightCard] = []
    @State private var analytics: AnalyticsData?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Loading insights...")
                            .padding()
                    } else {
                        // Insights Grid
                        if !insights.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Insights")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ForEach(insights) { insight in
                                        InsightCardView(insight: insight) {
                                            // Handle insight tap
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Analytics Summary
                        if let analytics = analytics {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Analytics Summary")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    AnalyticsCard(
                                        title: "Total Days",
                                        value: "\(analytics.summary.total_days)",
                                        icon: "calendar",
                                        color: .blue
                                    )
                                    AnalyticsCard(
                                        title: "Total Steps",
                                        value: "\(analytics.summary.total_steps)",
                                        icon: "figure.walk",
                                        color: .green
                                    )
                                    AnalyticsCard(
                                        title: "Water Intake",
                                        value: String(format: "%.1fL", analytics.summary.total_water_liters),
                                        icon: "drop.fill",
                                        color: .blue
                                    )
                                    AnalyticsCard(
                                        title: "Risk %",
                                        value: String(format: "%.1f%%", analytics.summary.dehydration_risk_percentage),
                                        icon: "exclamationmark.triangle.fill",
                                        color: .red
                                    )
                                }
                                .padding(.horizontal)
                                
                                // Trends Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Trends")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    VStack(spacing: 12) {
                                        HStack {
                                            Image(systemName: "chart.line.uptrend.xyaxis")
                                                .foregroundColor(.green)
                                            VStack(alignment: .leading) {
                                                Text("Water Intake Trend")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text(analytics.trends.water_intake_trend.capitalized)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        
                                        HStack {
                                            Image(systemName: "drop.fill")
                                                .foregroundColor(.blue)
                                            VStack(alignment: .leading) {
                                                Text("Recent Average")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text("\(analytics.trends.recent_avg_water, specifier: "%.2f")L")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                        
                                        HStack {
                                            Image(systemName: "drop.fill")
                                                .foregroundColor(.blue)
                                            VStack(alignment: .leading) {
                                                Text("Overall Average")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text("\(analytics.trends.overall_avg_water, specifier: "%.2f")L")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        if insights.isEmpty && analytics == nil {
                            VStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                Text("No Insights Yet")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Keep using the app to generate personalized insights!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Insights")
            .onAppear {
                loadInsights()
                loadAnalytics()
            }
        }
    }
    
    private func loadInsights() {
        guard let url = URL(string: "\(serverURL)/user/\(userId)/insights") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to fetch insights:", error)
                    return
                }
                
                guard let data = data,
                      let insights = try? JSONDecoder().decode([InsightCard].self, from: data) else {
                    return
                }
                
                self.insights = insights
            }
        }.resume()
    }
    
    private func loadAnalytics() {
        isLoading = true
        guard let url = URL(string: "\(serverURL)/user/\(userId)/analytics") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("Failed to load analytics:", error)
                    return
                }
                guard let data = data,
                      let analytics = try? JSONDecoder().decode(AnalyticsData.self, from: data) else {
                    return
                }
                self.analytics = analytics
            }
        }.resume()
    }
}

struct ContentView: View {
    @State private var healthMetrics: [HealthMetric] = []
    @State private var accX: Double = 0.0
    @State private var accY: Double = 0.0
    @State private var accZ: Double = 0.0
    @State private var steps: Double = 0.0
    @State private var activeEnergy: Double = 0.0
    @State private var waterIntake: Double = 0.0
    @State private var isConnected: Bool = false
    @State private var lastUpdateTime: Date = Date()
    // Advance dehydration risk states
    @State private var dehydrationStatus: String = "Loading..."
    @State private var dehydrationRisk: String = "Loading..."
    @State private var dehydrationReason: String = ""
    @State private var dehydrationTime: String? = nil
    @State private var userAlerts: [Alert] = []
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var personalRecommendations: [String] = []
    @State private var modelStatus: ModelStatus = ModelStatus()
    @State private var weatherData: WeatherData?
    
    // New feature states
    @State private var coachSuggestions: [CoachSuggestion] = []
    @State private var riskPrediction: RiskPrediction?
    @State private var hydrationStreak = HydrationStreak(currentStreak: 0, longestStreak: 0, lastLogDate: nil, dailyGoal: 2.5, todayProgress: 0.0)
    @State private var insights: [InsightCard] = []
    @State private var selectedTheme = AppTheme.themes[0] // Professional Dark
    @State private var showingQuickLog = false
    @State private var queuedMetrics: [QueuedMetric] = []
    @State private var lastSyncTime: Date?
    @State private var anomalyAlerts: [String] = []
    @State private var reminderSettings = ReminderSettings()
    @State private var showingThemeSelector = false
    
    // Timers for new features
    private let riskPredictionTimer = Timer.publish(every: 900, on: .main, in: .common).autoconnect() // 15 min
    private let anomalyCheckTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect() // 5 min
    
    let healthStore = HKHealthStore()
    let motionManager = CMMotionManager()
    // Use Mac's IP address for real device testing
    let serverURL = "http://192.168.1.75:5000"
    
    // Configure URLSession with better defaults
    let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    let riskTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    let alertTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect() // Check alerts every 5 minutes
    
    // For now, use device identifier as user_id
    let userId = UIDevice.current.identifierForVendor?.uuidString ?? "default_user"
    // Reusable grid definition to help the type-checker
    let gridColumnsTwo: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    // Extracted to ease SwiftUI type-checking
    @ViewBuilder
    private var metricsContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Modern Header Card
                    Group {
                        ModernHeaderCard(
                            status: dehydrationStatus,
                            risk: dehydrationRisk,
                            reason: dehydrationReason,
                            time: dehydrationTime
                        )
                    }

                    // Weather Card
                    Group { if let weather = weatherData { WeatherSection(weather: weather) } }

                    // Model Status Card
                    Group { if modelStatus.has_personal_model { ModelStatusCardView(status: modelStatus) } }

                    // Connection Status
                    ConnectionStatusRow(isConnected: isConnected, lastUpdate: lastUpdateTime)

                    // Alerts Section
                    Group { if !userAlerts.isEmpty { AlertsSectionView(alerts: userAlerts) } }

                    // Main Metrics Grid
                    MetricsGridView(metrics: healthMetrics, steps: steps, activeEnergy: activeEnergy, waterIntake: waterIntake, columns: gridColumnsTwo)

                    // Accelerometer Data
                    MotionSectionView(accX: accX, accY: accY, accZ: accZ)

                    // Send Button
                    SendButtonView(action: { sendToServer() })
                    
                    // Manual Refresh Button
                    Button(action: {
                        testServerConnection()
                        fetchDehydrationRisk()
                        fetchUserAlerts()
                        fetchModelStatus()
                        fetchWeatherData()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                            Text("Refresh Connection")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    
                    // HealthKit Refresh Button
                    Button(action: {
                        debugHealthKitData()  // Add debugging first
                        requestAndFetchHealthData()
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                            Text("Refresh Health Data")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }
            .navigationTitle("HydraFlow")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.9),
                        Color.indigo.opacity(0.1),
                        Color.black.opacity(0.95)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ),
                for: .navigationBar
            )
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.95),
                        Color.indigo.opacity(0.1),
                        Color.black.opacity(0.98)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .onAppear {
                requestAndFetchHealthData()
                startAccelerometerUpdates()
                testServerConnection()
                fetchDehydrationRisk()
                fetchUserAlerts()
                fetchModelStatus()
                fetchWeatherData()
            }
            .onReceive(timer) { _ in
                sendToServer()
            }
            .onReceive(riskTimer) { _ in
                fetchDehydrationRisk()
            }
            .onReceive(alertTimer) { _ in
                fetchUserAlerts()
            }
            .alert("Hydration Alert", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    var body: some View {
        TabView {
            // extracted metrics tab to a separate builder to ease type-checking
            metricsContent
            .tabItem {
                Label("Dashboard", systemImage: "heart.fill")
            }

            // New Coach Tab (fills the empty second tab)
            CoachView(
                userId: userId,
                serverURL: serverURL,
                healthMetrics: healthMetrics,
                steps: steps,
                activeEnergy: activeEnergy,
                waterIntake: waterIntake,
                weatherData: weatherData,
                dehydrationRisk: dehydrationRisk
            )
            .tabItem {
                Label("AI Coach", systemImage: "brain.head.profile")
            }

            // New Insights Tab (enhanced analytics with mini cards)
            InsightsView(userId: userId, serverURL: serverURL)
            .tabItem {
                Label("Analytics", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            NavigationStack {
                AchievementsView(userId: userId, serverURL: serverURL)
            }
            .tabItem {
                Label("Achievements", systemImage: "trophy.fill")
            }
            
            ChatbotView()
                .tabItem {
                    Label("Assistant", systemImage: "message.circle")
                }
            
            // Settings Tab with themes and preferences
            SettingsView(selectedTheme: $selectedTheme, reminderSettings: $reminderSettings)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.95),
                    Color.indigo.opacity(0.1),
                    Color.black.opacity(0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .accentColor(.indigo) // Professional accent color
        .preferredColorScheme(.dark) // Force dark mode for professional look
        .sheet(isPresented: $showingQuickLog) {
            QuickLogSheet(
                isPresented: $showingQuickLog,
                onLog: { amount in
                    logWaterIntake(amount)
                },
                dailyGoal: hydrationStreak.dailyGoal,
                currentProgress: hydrationStreak.todayProgress
            )
        }
        .onReceive(riskTimer) { _ in
            fetchRiskPrediction()
        }
        .onReceive(alertTimer) { _ in
            checkForAnomalies()
        }
        .onAppear {
            setupNotifications()
            loadOfflineQueue()
            updateHydrationStreak()
            checkHealthKitPermissions()
            requestAndFetchHealthData()
        }
    }
    
    func requestAndFetchHealthData() {
        guard HKHealthStore.isHealthDataAvailable() else { 
            print("HealthKit is not available on this device")
            setDefaultHealthValues()
            return 
        }
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        ]
        
        print("Requesting HealthKit authorization...")
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed:", error)
            }
            
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization successful, fetching metrics...")
                    // Add a small delay to ensure authorization is fully processed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.debugHealthKitData()  // Debug after authorization
                        self.fetchAllMetrics()
                    }
                } else {
                    print("HealthKit authorization denied")
                    // Set default values when authorization is denied
                    self.setDefaultHealthValues()
                }
            }
        }
    }
    
    func checkHealthKitPermissions() {
        let typesToCheck: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        ]
        
        for type in typesToCheck {
            let status = healthStore.authorizationStatus(for: type)
            print("HealthKit permission for \(type.identifier): \(status.rawValue)")
        }
    }
    
    func debugHealthKitData() {
        print("=== HEALTHKIT DEBUGGING ===")
        
        // Check if HealthKit is available
        print("HealthKit available: \(HKHealthStore.isHealthDataAvailable())")
        
        // Check permissions for each type
        let typesToCheck: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        ]
        
        for type in typesToCheck {
            let status = healthStore.authorizationStatus(for: type)
            print("Permission for \(type.identifier): \(status.rawValue)")
            
            // Try to fetch a sample to see what's available
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 5, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("Error querying \(type.identifier): \(error)")
                    return
                }
                
                if let samples = samples, !samples.isEmpty {
                    print("Found \(samples.count) samples for \(type.identifier)")
                    for (index, sample) in samples.enumerated() {
                        if let quantitySample = sample as? HKQuantitySample {
                            print("  Sample \(index): \(quantitySample.quantity) at \(quantitySample.startDate)")
                        }
                    }
                } else {
                    print("No samples found for \(type.identifier)")
                }
            }
            healthStore.execute(query)
        }
    }
    
    func fetchAllMetrics() {
        print("Fetching all HealthKit metrics...")
        fetchLatestQuantity(for: .heartRate, unit: .count().unitDivided(by: .minute()), name: "HR", color: .red, icon: "heart.fill")
        fetchLatestQuantity(for: .bodyTemperature, unit: .degreeCelsius(), name: "Temp", color: .orange, icon: "thermometer")
        fetchSumQuantity(for: .stepCount, unit: .count(), name: "Steps")
        fetchSumQuantity(for: .activeEnergyBurned, unit: .kilocalorie(), name: "Active Energy")
        fetchSumQuantity(for: .dietaryWater, unit: .liter(), name: "Water Intake")
    }
    
    func setDefaultHealthValues() {
        print("Setting default health values...")
        // Set "No data" indicators when HealthKit data is not available
        updateMetric(name: "HR", value: "No data", unit: "", color: .gray, icon: "heart.fill")
        updateMetric(name: "Temp", value: "No data", unit: "", color: .gray, icon: "thermometer")
        steps = 0 // No data available
        activeEnergy = 0 // No data available
        waterIntake = 0 // No data available
        
        print("Default values set - No HealthKit data available")
    }
    
    func fetchLatestQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, name: String, color: Color, icon: String) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { 
            print("Failed to get HealthKit type for \(name)")
            return 
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Error fetching \(name):", error)
                return
            }
            
            if let sample = samples?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: unit)
                print("\(name): \(value)")
                DispatchQueue.main.async {
                    if name == "HR" {
                        self.updateMetric(name: name, value: String(format: "%.1f", value), unit: "bpm", color: color, icon: icon)
                    } else if name == "Temp" {
                        self.updateMetric(name: name, value: String(format: "%.1f", value), unit: "°C", color: color, icon: icon)
                    }
                }
            } else {
                print("No \(name) data available in HealthKit")
                // Set "No data" indicator if no data available
                DispatchQueue.main.async {
                    if name == "HR" {
                        self.updateMetric(name: name, value: "No data", unit: "", color: .gray, icon: icon)
                    } else if name == "Temp" {
                        self.updateMetric(name: name, value: "No data", unit: "", color: .gray, icon: icon)
                    }
                }
            }
        }
        healthStore.execute(query)
    }
    
    func fetchSumQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, name: String) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { 
            print("Failed to get HealthKit type for \(name)")
            return 
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        print("Fetching \(name) from \(startOfDay) to now...")
        
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("Error fetching \(name):", error)
                return
            }
            
            var value = 0.0
            if let sum = result?.sumQuantity() {
                value = sum.doubleValue(for: unit)
                print("\(name): \(value)")
            } else {
                print("No \(name) data available for today")
                // Keep value as 0 when no data available
                value = 0.0
                print("No data available for \(name), keeping as 0")
            }
            
            DispatchQueue.main.async {
                if name == "Steps" {
                    self.steps = value
                } else if name == "Active Energy" {
                    self.activeEnergy = value
                } else if name == "Water Intake" {
                    self.waterIntake = value
                }
            }
        }
        healthStore.execute(query)
    }
    
    func updateMetric(name: String, value: String, unit: String, color: Color, icon: String) {
        if let idx = healthMetrics.firstIndex(where: { $0.title == name }) {
            healthMetrics[idx] = HealthMetric(title: name, value: value, unit: unit, color: color, icon: icon)
        } else {
            healthMetrics.append(HealthMetric(title: name, value: value, unit: unit, color: color, icon: icon))
        }
    }
    
    func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0
            motionManager.startAccelerometerUpdates(to: .main) { data, _ in
                if let data = data {
                    accX = data.acceleration.x
                    accY = data.acceleration.y
                    accZ = data.acceleration.z
                }
            }
        }
    }
    
    func sendToServer() {
        // Enhanced with offline queue support
        let temp = healthMetrics.first(where: { $0.title == "Temp" })?.value ?? "No data"
        let hr = healthMetrics.first(where: { $0.title == "HR" })?.value ?? "No data"
        let stepsValue = steps
        let activeEnergyValue = activeEnergy
        let waterIntakeValue = waterIntake
        let payload: [String: Any] = [
            "user_id": userId,
            "Temp": temp,
            "HR": hr,
            "Acc_X": accX,
            "Acc_Y": accY,
            "Acc_Z": accZ,
            "EDA": 0,
            "Steps": stepsValue,
            "Active Energy": activeEnergyValue,
            "Water Intake": waterIntakeValue
        ]
        print("Sending to server:", payload)
        guard let url = URL(string: "\(serverURL)/update_metrics") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // 10 second timeout
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("Failed to encode payload:", error)
            return
        }
        
        let task = self.urlSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("POST failed:", error)
                    if (error as NSError).code == NSURLErrorTimedOut {
                        self.dehydrationReason = "The request timed out."
                    } else {
                        self.dehydrationReason = error.localizedDescription
                    }
                    self.isConnected = false
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("Server responded with status:", httpResponse.statusCode)
                    self.isConnected = httpResponse.statusCode == 200
                    self.lastUpdateTime = Date()
                    
                    // Sync queued metrics when connection is restored
                    if self.isConnected {
                        self.syncQueuedMetrics()
                    }
                } else {
                    // Queue for offline sync
                    self.queueMetricForSync(payload: payload, endpoint: "/update_metrics")
                }
                
                // Parse response for recommendations and weather
                if let data = data,
                   let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let recommendations = responseDict["recommendations"] as? [String] {
                        self.personalRecommendations = recommendations
                    }
                    if let weatherDict = responseDict["weather"] as? [String: Any] {
                        self.weatherData = WeatherData(
                            temperature: weatherDict["temperature"] as? Double ?? 0,
                            humidity: weatherDict["humidity"] as? Int ?? 0,
                            description: weatherDict["description"] as? String ?? ""
                        )
                    }
                }
            }
        }.resume()
    }
    
    // Fetch advance dehydration risk from backend
    func fetchDehydrationRisk() {
        guard let url = URL(string: "\(serverURL)/predict_dehydration_risk") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10 second timeout
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Dehydration risk fetch failed:", error)
                    self.dehydrationStatus = "Unavailable"
                    self.dehydrationRisk = "Unavailable"
                    
                    if (error as NSError).code == NSURLErrorTimedOut {
                        self.dehydrationReason = "The request timed out."
                    } else {
                        self.dehydrationReason = error.localizedDescription
                    }
                    self.dehydrationTime = nil
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.dehydrationStatus = "Unavailable"
                    self.dehydrationRisk = "Unavailable"
                    self.dehydrationReason = "No data"
                    self.dehydrationTime = nil
                    return
                }
                self.dehydrationStatus = json["current_status"] as? String ?? "Unknown"
                self.dehydrationRisk = json["future_risk"] as? String ?? "Unknown"
                self.dehydrationReason = json["reason"] as? String ?? ""
                self.dehydrationTime = json["time_to_dehydration"] as? String
            }
        }.resume()
    }
    
    // Fetch user alerts
    func fetchUserAlerts() {
        guard let url = URL(string: "\(serverURL)/user/\(userId)/alerts") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to fetch alerts:", error)
                    return
                }
                guard let data = data,
                      let alerts = try? JSONDecoder().decode([Alert].self, from: data) else {
                    return
                }
                self.userAlerts = alerts
                
                // Show alert for new high-risk alerts
                for alert in alerts {
                    if alert.risk_level > 0.7 && !alert.is_read {
                        self.alertMessage = alert.message
                        self.showingAlert = true
                    }
                }
            }
        }.resume()
    }
    
    // Fetch model status
    func fetchModelStatus() {
        guard let url = URL(string: "\(serverURL)/user/\(userId)/model_status") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to fetch model status:", error)
                    return
                }
                guard let data = data,
                      let status = try? JSONDecoder().decode(ModelStatus.self, from: data) else {
                    return
                }
                self.modelStatus = status
            }
        }.resume()
    }
    
    // Test server connection
    func testServerConnection() {
        guard let url = URL(string: "\(serverURL)/health") else { 
            print("Invalid server URL: \(serverURL)")
            return 
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout for health check
        
        print("Testing connection to: \(serverURL)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Connection test failed:", error)
                    if (error as NSError).code == NSURLErrorTimedOut {
                        self.dehydrationReason = "Server connection timed out. Check if backend is running."
                    } else if (error as NSError).code == NSURLErrorCannotConnectToHost {
                        self.dehydrationReason = "Cannot connect to server. Check IP address and port."
                    } else {
                        self.dehydrationReason = "Connection failed: \(error.localizedDescription)"
                    }
                    self.isConnected = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Connection test successful. Status: \(httpResponse.statusCode)")
                    self.isConnected = true
                    self.dehydrationReason = ""
                } else {
                    print("Connection test failed: Invalid response")
                    self.isConnected = false
                    self.dehydrationReason = "Invalid server response"
                }
            }
        }
        task.resume()
    }
    
    // Fetch weather data
    func fetchWeatherData() {
        guard let url = URL(string: "\(serverURL)/weather") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0 // 10 second timeout
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to fetch weather:", error)
                    return
                }
                guard let data = data,
                      let weather = try? JSONDecoder().decode(WeatherData.self, from: data) else {
                    return
                }
                self.weatherData = weather
            }
        }
        task.resume()
    }
}

// Alert model for database alerts
struct Alert: Codable, Identifiable {
    let id: Int
    let user_id: String
    let alert_type: String
    let message: String
    let risk_level: Double
    let timestamp: String
    let is_read: Bool
}

// Model status for personal ML
struct ModelStatus: Codable {
    let has_personal_model: Bool
    let total_records: Int
    let model_type: String
    
    init() {
        self.has_personal_model = false
        self.total_records = 0
        self.model_type = "global"
    }
}

// Data models for advanced features
struct AnalyticsData: Codable {
    let summary: AnalyticsSummary
    let trends: AnalyticsTrends
    let best_day: AnalyticsDay
    let worst_day: AnalyticsDay
}

struct AnalyticsSummary: Codable {
    let total_days: Int
    let total_steps: Int
    let total_water_liters: Double
    let avg_heart_rate: Double
    let dehydration_risk_percentage: Double
}

struct AnalyticsTrends: Codable {
    let water_intake_trend: String
    let recent_avg_water: Double
    let overall_avg_water: Double
}

struct AnalyticsDay: Codable {
    let date: String
    let water_intake: Double
    let steps: Int
}

struct Achievement: Codable, Identifiable {
    let id: Int
    let user_id: String
    let achievement_type: String
    let message: String
    let earned_at: String
}

struct WeatherData: Codable {
    let temperature: Double
    let humidity: Int
    let description: String
}

// MARK: - Enhanced ContentView Extension

extension ContentView {
    
    // MARK: - New Feature Functions
    
    func logWaterIntake(_ amount: Int) {
        let liters = Double(amount) / 1000.0
        waterIntake += liters
        hydrationStreak.todayProgress += liters
        
        // Update streak if goal is met
        if hydrationStreak.todayProgress >= hydrationStreak.dailyGoal {
            if let lastLog = hydrationStreak.lastLogDate,
               Calendar.current.isDate(lastLog, inSameDayAs: Date()) {
                // Already logged today, don't increment streak
            } else {
                hydrationStreak.currentStreak += 1
                if hydrationStreak.currentStreak > hydrationStreak.longestStreak {
                    hydrationStreak.longestStreak = hydrationStreak.currentStreak
                }
            }
            hydrationStreak.lastLogDate = Date()
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Queue for offline sync
        let payload: [String: Any] = [
            "user_id": userId,
            "water_amount": amount,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        queueMetricForSync(payload: payload, endpoint: "/log_water")
        
        print("Logged \(amount)ml of water. Total today: \(String(format: "%.1f", hydrationStreak.todayProgress))L")
    }
    
    func fetchRiskPrediction() {
        guard let url = URL(string: "\(serverURL)/predict_risk_eta") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "user_id": userId,
            "current_metrics": [
                "temperature": healthMetrics.first(where: { $0.title == "Temp" })?.value ?? "36.5",
                "heart_rate": healthMetrics.first(where: { $0.title == "HR" })?.value ?? "70",
                "steps": steps,
                "water_intake": waterIntake,
                "weather_temp": weatherData?.temperature ?? 20
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to encode risk prediction payload:", error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Risk prediction failed:", error)
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                
                let eta = json["eta"] as? String ?? "Unknown"
                let confidence = json["confidence"] as? Double ?? 0.0
                let factorsData = json["factors"] as? [[String: Any]] ?? []
                
                let factors = factorsData.compactMap { factorDict -> RiskFactor? in
                    guard let name = factorDict["name"] as? String,
                          let impact = factorDict["impact"] as? Double,
                          let description = factorDict["description"] as? String else {
                        return nil
                    }
                    return RiskFactor(name: name, impact: impact, description: description)
                }
                
                self.riskPrediction = RiskPrediction(
                    eta: eta,
                    confidence: confidence,
                    factors: factors,
                    timestamp: Date()
                )
            }
        }.resume()
    }
    
    func checkForAnomalies() {
        // Simple anomaly detection logic
        let currentHR = Double(healthMetrics.first(where: { $0.title == "HR" })?.value ?? "70") ?? 70
        let currentTemp = Double(healthMetrics.first(where: { $0.title == "Temp" })?.value ?? "36.5") ?? 36.5
        
        // Check for high HR with low activity
        if currentHR > 100 && steps < 1000 {
            let anomaly = "High heart rate (\(Int(currentHR)) BPM) detected with low activity. Consider hydrating and resting."
            if !anomalyAlerts.contains(anomaly) && anomalyAlerts.count < 2 {
                anomalyAlerts.append(anomaly)
                showAnomalyAlert(anomaly)
            }
        }
        
        // Check for high temperature
        if currentTemp > 37.5 {
            let anomaly = "Elevated body temperature (\(String(format: "%.1f", currentTemp))°C) detected. Increase fluid intake."
            if !anomalyAlerts.contains(anomaly) && anomalyAlerts.count < 2 {
                anomalyAlerts.append(anomaly)
                showAnomalyAlert(anomaly)
            }
        }
    }
    
    func showAnomalyAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
        
        // Add haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                self.scheduleSmartReminders()
            }
        }
    }
    
    func scheduleSmartReminders() {
        guard reminderSettings.isEnabled else { return }
        
        // Cancel existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if reminderSettings.contextAware {
            // Schedule context-aware reminders based on activity and weather
            scheduleContextAwareReminder()
        } else {
            // Schedule regular interval reminders
            scheduleRegularReminder()
        }
    }
    
    func scheduleContextAwareReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Smart Hydration Reminder"
        
        // Customize message based on context
        if let weather = weatherData, weather.temperature > 25 {
            content.body = "It's \(String(format: "%.0f", weather.temperature))°C outside. Time to hydrate! 💧"
        } else if steps > 5000 {
            content.body = "Great job on staying active! Don't forget to hydrate. 🚶‍♂️💧"
        } else {
            content.body = "Time for a hydration break! Your body will thank you. 💧"
        }
        
        content.sound = .default
        content.categoryIdentifier = "HYDRATION_REMINDER"
        
        // Schedule for next hour, respecting quiet hours
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(reminderSettings.intervalMinutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "smart_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleRegularReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Hydration Reminder"
        content.body = "Time to drink some water! 💧"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(reminderSettings.intervalMinutes * 60), repeats: true)
        let request = UNNotificationRequest(identifier: "regular_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func queueMetricForSync(payload: [String: Any], endpoint: String) {
        let queuedMetric = QueuedMetric(payload: payload, endpoint: endpoint)
        queuedMetrics.append(queuedMetric)
        saveOfflineQueue()
        
        // Try to sync immediately if connected
        if isConnected {
            syncQueuedMetrics()
        }
    }
    
    func syncQueuedMetrics() {
        guard !queuedMetrics.isEmpty else { return }
        
        let metricsToSync = queuedMetrics
        
        for metric in metricsToSync {
            guard let url = URL(string: "\(serverURL)\(metric.endpoint)") else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: metric.payload)
            } catch {
                continue
            }
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        // Remove successfully synced metric
                        if let index = self.queuedMetrics.firstIndex(where: { $0.id == metric.id }) {
                            self.queuedMetrics.remove(at: index)
                            self.saveOfflineQueue()
                        }
                    }
                }
            }.resume()
        }
        
        // Show sync status
        if !queuedMetrics.isEmpty {
            lastSyncTime = Date()
            print("Synced \(metricsToSync.count - queuedMetrics.count) items")
        }
    }
    
    func saveOfflineQueue() {
        if let encoded = try? JSONEncoder().encode(queuedMetrics) {
            UserDefaults.standard.set(encoded, forKey: "queued_metrics_\(userId)")
        }
    }
    
    func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: "queued_metrics_\(userId)"),
           let decoded = try? JSONDecoder().decode([QueuedMetric].self, from: data) {
            queuedMetrics = decoded
        }
    }
    
    func updateHydrationStreak() {
        // Load saved streak data
        if let data = UserDefaults.standard.data(forKey: "hydration_streak_\(userId)"),
           let decoded = try? JSONDecoder().decode(HydrationStreak.self, from: data) {
            hydrationStreak = decoded
        }
        
        // Reset daily progress if it's a new day
        if let lastLog = hydrationStreak.lastLogDate,
           !Calendar.current.isDate(lastLog, inSameDayAs: Date()) {
            hydrationStreak.todayProgress = waterIntake
        }
        
        // Save updated streak
        if let encoded = try? JSONEncoder().encode(hydrationStreak) {
            UserDefaults.standard.set(encoded, forKey: "hydration_streak_\(userId)")
        }
    }
}

struct CoachView: View {
    let userId: String
    let serverURL: String
    let healthMetrics: [HealthMetric]
    let steps: Double
    let activeEnergy: Double
    let waterIntake: Double
    let weatherData: WeatherData?
    let dehydrationRisk: String
    
    @State private var coachSuggestions: [CoachSuggestion] = []
    @State private var riskPrediction: RiskPrediction?
    @State private var hydrationStreak = HydrationStreak(currentStreak: 0, longestStreak: 0, lastLogDate: nil, dailyGoal: 2.5, todayProgress: 0.0)
    @State private var insights: [InsightCard] = []
    @State private var showingQuickLog = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Coach Suggestions
                    if !coachSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Today's Suggestions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(coachSuggestions) { suggestion in
                                CoachCard(suggestion: suggestion) { action in
                                    handleQuickAction(action)
                                }
                            }
                        }
                    }
                    
                    // Risk ETA Panel
                    RiskETAPanel(prediction: riskPrediction)
                    
                    // Hydration Streak
                    StreakCard(streak: hydrationStreak)
                    
                    // Quick Log Button
                    Button(action: { showingQuickLog = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Log Water Intake")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // Insights Grid
                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Insights")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(insights) { insight in
                                    InsightCardView(insight: insight) {
                                        // Handle insight tap
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Hydration Coach")
            .navigationBarTitleDisplayMode(.large)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBackground)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .onAppear {
                loadCoachData()
            }
            .sheet(isPresented: $showingQuickLog) {
                QuickLogSheet(
                    isPresented: $showingQuickLog,
                    onLog: { amount in
                        logWaterIntake(amount)
                    },
                    dailyGoal: hydrationStreak.dailyGoal,
                    currentProgress: hydrationStreak.todayProgress
                )
            }
        }
    }
    
    private func loadCoachData() {
        // Load coach suggestions, risk prediction, and insights
        fetchCoachSuggestions()
        fetchRiskPrediction()
        fetchInsights()
        updateHydrationStreak()
    }
    
    private func fetchCoachSuggestions() {
        guard let url = URL(string: "\(serverURL)/coach/suggestions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "user_id": userId,
            "current_metrics": [
                "temperature": healthMetrics.first(where: { $0.title == "Temp" })?.value ?? "36.5",
                "heart_rate": healthMetrics.first(where: { $0.title == "HR" })?.value ?? "70",
                "steps": steps,
                "water_intake": waterIntake,
                "weather_temp": weatherData?.temperature ?? 20,
                "dehydration_risk": dehydrationRisk
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to encode coach suggestions payload:", error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Coach suggestions failed:", error)
                    return
                }
                
                guard let data = data,
                      let suggestions = try? JSONDecoder().decode([CoachSuggestion].self, from: data) else {
                    return
                }
                
                self.coachSuggestions = suggestions
            }
        }.resume()
    }
    
    private func fetchRiskPrediction() {
        guard let url = URL(string: "\(serverURL)/predict_risk_eta") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "user_id": userId,
            "current_metrics": [
                "temperature": healthMetrics.first(where: { $0.title == "Temp" })?.value ?? "36.5",
                "heart_rate": healthMetrics.first(where: { $0.title == "HR" })?.value ?? "70",
                "steps": steps,
                "water_intake": waterIntake,
                "weather_temp": weatherData?.temperature ?? 20
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Failed to encode risk prediction payload:", error)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Risk prediction failed:", error)
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                
                let eta = json["eta"] as? String ?? "Unknown"
                let confidence = json["confidence"] as? Double ?? 0.0
                let factorsData = json["factors"] as? [[String: Any]] ?? []
                
                let factors = factorsData.compactMap { factorDict -> RiskFactor? in
                    guard let name = factorDict["name"] as? String,
                          let impact = factorDict["impact"] as? Double,
                          let description = factorDict["description"] as? String else {
                        return nil
                    }
                    return RiskFactor(name: name, impact: impact, description: description)
                }
                
                self.riskPrediction = RiskPrediction(
                    eta: eta,
                    confidence: confidence,
                    factors: factors,
                    timestamp: Date()
                )
            }
        }.resume()
    }
    

    
    private func fetchInsights() {
        guard let url = URL(string: "\(serverURL)/user/\(userId)/insights") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to fetch insights:", error)
                    return
                }
                
                guard let data = data,
                      let insights = try? JSONDecoder().decode([InsightCard].self, from: data) else {
                    return
                }
                
                self.insights = insights
            }
        }.resume()
    }
    
    private func updateHydrationStreak() {
        // Load saved streak data
        if let data = UserDefaults.standard.data(forKey: "hydration_streak_\(userId)"),
           let decoded = try? JSONDecoder().decode(HydrationStreak.self, from: data) {
            hydrationStreak = decoded
        }
        
        // Reset daily progress if it's a new day
        if let lastLog = hydrationStreak.lastLogDate,
           !Calendar.current.isDate(lastLog, inSameDayAs: Date()) {
            hydrationStreak.todayProgress = waterIntake
        }
        
        // Save updated streak
        if let encoded = try? JSONEncoder().encode(hydrationStreak) {
            UserDefaults.standard.set(encoded, forKey: "hydration_streak_\(userId)")
        }
    }
    
    private func logWaterIntake(_ amount: Int) {
        let liters = Double(amount) / 1000.0
        hydrationStreak.todayProgress += liters
        
        // Update streak if goal is met
        if hydrationStreak.todayProgress >= hydrationStreak.dailyGoal {
            if let lastLog = hydrationStreak.lastLogDate,
               Calendar.current.isDate(lastLog, inSameDayAs: Date()) {
                // Already logged today, don't increment streak
            } else {
                hydrationStreak.currentStreak += 1
                if hydrationStreak.currentStreak > hydrationStreak.longestStreak {
                    hydrationStreak.longestStreak = hydrationStreak.currentStreak
                }
            }
            hydrationStreak.lastLogDate = Date()
        }
        
        // Save updated streak
        if let encoded = try? JSONEncoder().encode(hydrationStreak) {
            UserDefaults.standard.set(encoded, forKey: "hydration_streak_\(userId)")
        }
        
        print("Logged \(amount)ml of water. Total today: \(String(format: "%.1f", hydrationStreak.todayProgress))L")
    }
    
    private func handleQuickAction(_ action: QuickAction) {
        switch action.type {
        case .logWater:
            showingQuickLog = true
        case .setReminder:
            // Handle setting reminder
            print("Setting reminder for \(action.amount)ml")
        }
    }
}
