import SwiftUI
import HealthKit
import CoreMotion

struct HealthMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
}

struct Developer: Identifiable {
    let id = UUID()
    let name: String
    let role: String
    let email: String
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct MetricCard: View {
    let metric: HealthMetric
    var body: some View {
        HStack {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(metric.color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: metric.icon)
                    .font(.title2)
                    .foregroundColor(metric.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(metric.value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(metric.color)
                    
                    Text(metric.unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
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
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
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
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
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
    
    let serverURL = "http://192.168.1.75:5000"
    
    var body: some View {
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
                .onChange(of: messages.count) { _ in
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
    }
    
    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            content: "Hello! I'm your hydration assistant. I can analyze your health metrics and provide personalized hydration advice. How can I help you today?",
            isUser: false,
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }
    
    private func checkConnection() {
        guard let url = URL(string: "\(serverURL)/latest_metrics") else { return }
        
        URLSession.shared.dataTask(with: url) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    isConnected = httpResponse.statusCode == 200
                } else {
                    isConnected = false
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
        messages.append(userMessage)
        inputText = ""
        
        // Show typing indicator
        isTyping = true
        
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
                isTyping = false
                
                if let error = error {
                    handleError("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    handleError("No response data")
                    return
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    let botMessage = ChatMessage(
                        content: responseString,
                        isUser: false,
                        timestamp: Date()
                    )
                    messages.append(botMessage)
                } else {
                    handleError("Failed to decode response")
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
        messages.append(errorMessage)
    }
}

// Extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
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
    let healthStore = HKHealthStore()
    let motionManager = CMMotionManager()
    let serverURL = "http://192.168.1.75:5000"
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    let riskTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Advance Dehydration Risk Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: dehydrationRisk == "High" ? "exclamationmark.triangle.fill" : (dehydrationRisk == "Moderate" ? "exclamationmark.circle.fill" : "checkmark.seal.fill"))
                                    .foregroundColor(dehydrationRisk == "High" ? .red : (dehydrationRisk == "Moderate" ? .yellow : .green))
                                    .font(.title)
                                VStack(alignment: .leading) {
                                    Text("Hydration Status: ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(dehydrationStatus)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Dehydration Risk (next 10–30 min): ")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(dehydrationRisk)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(dehydrationRisk == "High" ? .red : (dehydrationRisk == "Moderate" ? .yellow : .green))
                                    if let time = dehydrationTime {
                                        Text(time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if !dehydrationReason.isEmpty {
                                        Text(dehydrationReason)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)
                        // Connection Status
                        HStack {
                            Circle()
                                .fill(isConnected ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text(isConnected ? "Connected to Server" : "Disconnected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Last update: \(lastUpdateTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Main Metrics Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach(healthMetrics) { metric in
                                MetricCard(metric: metric)
                            }
                            
                            // Additional metrics
                            MetricCard(metric: HealthMetric(
                                title: "Steps",
                                value: String(format: "%.0f", steps),
                                unit: "",
                                color: .green,
                                icon: "figure.walk"
                            ))
                            
                            MetricCard(metric: HealthMetric(
                                title: "Active Energy",
                                value: String(format: "%.0f", activeEnergy),
                                unit: "kcal",
                                color: .orange,
                                icon: "flame"
                            ))
                            
                            MetricCard(metric: HealthMetric(
                                title: "Water Intake",
                                value: String(format: "%.1f", waterIntake),
                                unit: "L",
                                color: .blue,
                                icon: "drop.fill"
                            ))
                        }
                        .padding(.horizontal)
                        
                        // Accelerometer Data
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Motion Data")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                StatusCard(
                                    title: "Acceleration X",
                                    value: String(format: "%.3f", accX),
                                    color: .purple,
                                    icon: "arrow.left.and.right"
                                )
                                
                                StatusCard(
                                    title: "Acceleration Y",
                                    value: String(format: "%.3f", accY),
                                    color: .purple,
                                    icon: "arrow.up.and.down"
                                )
                                
                                StatusCard(
                                    title: "Acceleration Z",
                                    value: String(format: "%.3f", accZ),
                                    color: .purple,
                                    icon: "arrow.up.and.down.circle"
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // Send Button
                        Button(action: {
                            sendToServer()
                        }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                    .font(.title3)
                                
                                Text("Send to Server")
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
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                }
                .navigationTitle("Hydration Monitor")
                .navigationBarTitleDisplayMode(.large)
                .onAppear {
                    requestAndFetchHealthData()
                    startAccelerometerUpdates()
                    fetchDehydrationRisk()
                }
                .onReceive(timer) { _ in
                    sendToServer()
                }
                .onReceive(riskTimer) { _ in
                    fetchDehydrationRisk()
                }
            }
            .tabItem {
                Label("Metrics", systemImage: "heart.fill")
            }
            
            ChatbotView()
                .tabItem {
                    Label("Chatbot", systemImage: "message.circle")
                }
            
            DeveloperView()
                .tabItem {
                    Label("Developers", systemImage: "person.3.fill")
                }
        }
    }
    
    func requestAndFetchHealthData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        ]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            if success {
                DispatchQueue.main.async {
                    fetchAllMetrics()
                }
            }
        }
    }
    
    func fetchAllMetrics() {
        fetchLatestQuantity(for: .heartRate, unit: .count().unitDivided(by: .minute()), name: "HR", color: .red, icon: "heart.fill")
        fetchLatestQuantity(for: .bodyTemperature, unit: .degreeCelsius(), name: "Temp", color: .orange, icon: "thermometer")
        fetchSumQuantity(for: .stepCount, unit: .count(), name: "Steps")
        fetchSumQuantity(for: .activeEnergyBurned, unit: .kilocalorie(), name: "Active Energy")
        fetchSumQuantity(for: .dietaryWater, unit: .liter(), name: "Water Intake")
    }
    
    func fetchLatestQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, name: String, color: Color, icon: String) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: unit)
                DispatchQueue.main.async {
                    if name == "HR" {
                        updateMetric(name: name, value: String(format: "%.1f", value), unit: "bpm", color: color, icon: icon)
                    } else if name == "Temp" {
                        updateMetric(name: name, value: String(format: "%.1f", value), unit: "°C", color: color, icon: icon)
                    }
                }
            }
        }
        healthStore.execute(query)
    }
    
    func fetchSumQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, name: String) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            var value = 0.0
            if let sum = result?.sumQuantity() {
                value = sum.doubleValue(for: unit)
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
        let temp = healthMetrics.first(where: { $0.title == "Temp" })?.value ?? "36.5"
        let hr = healthMetrics.first(where: { $0.title == "HR" })?.value ?? "0"
        let stepsValue = steps
        let activeEnergyValue = activeEnergy
        let waterIntakeValue = waterIntake
        let payload: [String: Any] = [
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
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("Failed to encode payload:", error)
            return
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("POST failed:", error)
                    isConnected = false
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    print("Server responded with status:", httpResponse.statusCode)
                    isConnected = httpResponse.statusCode == 200
                    lastUpdateTime = Date()
                }
            }
        }.resume()
    }
    
    // Fetch advance dehydration risk from backend
    func fetchDehydrationRisk() {
        guard let url = URL(string: "\(serverURL)/predict_dehydration_risk") else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    dehydrationStatus = "Unavailable"
                    dehydrationRisk = "Unavailable"
                    dehydrationReason = error.localizedDescription
                    dehydrationTime = nil
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    dehydrationStatus = "Unavailable"
                    dehydrationRisk = "Unavailable"
                    dehydrationReason = "No data"
                    dehydrationTime = nil
                    return
                }
                dehydrationStatus = json["current_status"] as? String ?? "Unknown"
                dehydrationRisk = json["future_risk"] as? String ?? "Unknown"
                dehydrationReason = json["reason"] as? String ?? ""
                dehydrationTime = json["time_to_dehydration"] as? String
            }
        }.resume()
    }
} 