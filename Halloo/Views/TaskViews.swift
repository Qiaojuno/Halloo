import SwiftUI

// MARK: - Task Views
// Component-based architecture for Task-related UI

// MARK: - Task Creation View
struct TaskCreationView: View {
    @EnvironmentObject var viewModel: TaskViewModel
    @Environment(\.presentationMode) var presentationMode
    let preselectedProfileId: String? // Profile ID to preselect for task creation
    
    init(preselectedProfileId: String? = nil) {
        self.preselectedProfileId = preselectedProfileId
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Custom Habit")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Task form would go here
                TaskCreationForm()
                
                Spacer()
                
                Button("Create Habit") {
                    // Create task action
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Set preselected profile when view appears
            if let profileId = preselectedProfileId {
                viewModel.preselectProfile(profileId: profileId)
            }
        }
    }
}

// MARK: - Task Form Component
struct TaskCreationForm: View {
    @State private var title = ""
    @State private var description = ""
    @State private var category: TaskCategory = .other
    @State private var frequency: TaskFrequency = .daily
    @State private var scheduledTime = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Habit Title", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Description", text: $description)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Picker("Category", selection: $category) {
                Text("Health").tag(TaskCategory.health)
                Text("Exercise").tag(TaskCategory.exercise)
                Text("Social").tag(TaskCategory.social)
                Text("Other").tag(TaskCategory.other)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Picker("Frequency", selection: $frequency) {
                Text("Daily").tag(TaskFrequency.daily)
                Text("Weekly").tag(TaskFrequency.weekly)
                Text("Custom").tag(TaskFrequency.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            DatePicker("Time", selection: $scheduledTime, displayedComponents: .hourAndMinute)
        }
    }
}

// MARK: - Task Row Component
struct TaskRow: View {
    let task: Task
    let profile: ElderlyProfile?
    let showViewButton: Bool
    let onViewTapped: (() -> Void)?
    
    init(task: Task, profile: ElderlyProfile? = nil, showViewButton: Bool = false, onViewTapped: (() -> Void)? = nil) {
        self.task = task
        self.profile = profile
        self.showViewButton = showViewButton
        self.onViewTapped = onViewTapped
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile image if provided
            if let profile = profile {
                ProfileImageSmall(profile: profile)
            }
            
            // Task details
            VStack(alignment: .leading, spacing: 4) {
                if let profile = profile {
                    Text(profile.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(task.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack {
                    Text(formatTime(task.scheduledTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if showViewButton {
                        Spacer()
                        Button("View") {
                            onViewTapped?()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Small Profile Image Component
struct ProfileImageSmall: View {
    let profile: ElderlyProfile
    
    var body: some View {
        AsyncImage(url: URL(string: profile.photoURL ?? "")) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.caption)
                        .fontWeight(.semibold)
                )
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

// MARK: - Task Card Component
struct TaskCard: View {
    let task: Task
    let onTap: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.category.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text(formatTime(task.scheduledTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(task.title)
                .font(.headline)
                .lineLimit(2)
            
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap?()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview Support
#if DEBUG
struct TaskViews_Previews: PreviewProvider {
    static var previews: some View {
        TaskCreationView()
            .environmentObject(Container.makeForTesting().makeTaskViewModel())
    }
}
#endif