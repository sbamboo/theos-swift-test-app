import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var token: String? = nil
    @State private var loggedInUserID: String? = nil // State variable to store the logged-in user's ID
    @State private var loginError: String? = nil
    @State private var fetchError: String? = nil
    @State private var isLoading: Bool = false
    @State private var messages: [[String: Any]] = []
    @State private var deleteMessageError: String? = nil // State variable for delete errors

    var body: some View {
        NavigationView {
            if token == nil {
                loginView
            } else {
                messagesView
            }
        }
    }

    var loginView: some View {
        VStack(spacing: 16) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Login") {
                login()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            if let error = loginError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .navigationTitle("Login")
    }

    var messagesView: some View {
        VStack {
            HStack {
                Text("Messages")
                    .font(.largeTitle)
                    .bold()

                Spacer()

                Button("Refresh") {
                    fetchMessages()
                }
                .padding(.horizontal)

                Button("Logout") {
                    logout()
                }
                .padding(.horizontal)
            }
            .padding()

            if let error = fetchError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            if let error = deleteMessageError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    LazyVStack { // Use LazyVStack for better performance with many items
                        ForEach(messages.indices, id: \.self) { index in
                            MessageRow(message: messages[index],
                                       loggedInUserID: loggedInUserID) { messageID in
                                // Closure called when "Remove" is tapped
                                deleteMessage(messageID: messageID)
                            }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Conversa")
        .onAppear {
            fetchMessages()
        }
    }

    func login() {
        guard let url = URL(string: "https://conversa-api.ntigskovde.se/conversa.php?validate&username=\(username)&password=\(password)") else { return }

        isLoading = true
        loginError = nil
        loggedInUserID = nil // Reset user ID on new login attempt

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }

            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        if let status = json["status"] as? String, status == "success" {
                            if let token = json["token"] as? String, !token.isEmpty {
                                self.token = token
                                self.loginError = nil
                                // Save the logged-in user's ID
                                self.loggedInUserID = json["id"] as? String // Assuming 'id' is the key for user ID
                            } else {
                                self.loginError = "Login failed: Missing token in response."
                            }
                        } else {
                            self.loginError = json["message"] as? String ?? "Unknown error"
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loginError = "Failed to decode server response."
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.loginError = "Network error: \(error?.localizedDescription ?? "Unknown")"
                }
            }
        }.resume()
    }

    func logout() {
        guard let token = token, let url = URL(string: "https://conversa-api.ntigskovde.se/conversa.php?logout&token=\(token)") else { return }

        URLSession.shared.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.async {
                self.token = nil
                self.username = ""
                self.password = ""
                self.messages = []
                self.fetchError = nil
                self.loggedInUserID = nil // Clear logged-in user ID on logout
                self.deleteMessageError = nil
            }
        }.resume()
    }

    func fetchMessages() {
        guard let token = token, let url = URL(string: "https://conversa-api.ntigskovde.se/conversa.php?getAll&token=\(token)") else { return }

        isLoading = true
        fetchError = nil

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }

            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    DispatchQueue.main.async {
                         // Check for a status in the first element if the array is not empty
                        if let firstMessage = json.first,
                           let status = firstMessage["status"] as? String, status != "success" {
                            self.fetchError = firstMessage["message"] as? String ?? "Failed fetching messages"
                            self.messages = []
                        } else {
                            // Assign a unique identifier to each message dictionary if it doesn't have one
                            // This helps SwiftUI differentiate views in ForEach
                            self.messages = json.map { message in
                                var mutableMessage = message
                                if mutableMessage["swiftuiID"] == nil {
                                    mutableMessage["swiftuiID"] = UUID().uuidString
                                }
                                return mutableMessage
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.fetchError = "Failed to decode messages."
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.fetchError = "Network error: \(error?.localizedDescription ?? "Unknown")"
                }
            }
        }.resume()
    }

    func deleteMessage(messageID: String) {
        guard let token = token, let url = URL(string: "https://conversa-api.ntigskovde.se/conversa.php?token=\(token)") else {
            self.deleteMessageError = "Invalid URL or token."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let postData: [String: Any] = [
            "delete": "1",
            "id": messageID
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])
        } catch {
            self.deleteMessageError = "Failed to create request body: \(error.localizedDescription)"
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.deleteMessageError = "Network error during deletion: \(error.localizedDescription)"
                    return
                }

                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let status = json["status"] as? String {
                    if status == "success" {
                        // Remove the deleted message from the local messages array
                        self.messages.removeAll { ($0["id"] as? String) == messageID }
                        self.deleteMessageError = nil // Clear any previous delete errors
                    } else {
                        self.deleteMessageError = json["message"] as? String ?? "Failed to delete message."
                    }
                } else {
                    self.deleteMessageError = "Failed to decode delete response."
                }
            }
        }.resume()
    }
}

struct MessageRow: View {
    let message: [String: Any]
    let loggedInUserID: String? // Pass the logged-in user ID
    let onDelete: (String) -> Void // Closure to call when deleting

    @State private var image: UIImage? = nil
    @State private var isLoadingImage: Bool = false

    // Helper to check if the current message is authored by the logged-in user
    private var isMyMessage: Bool {
        guard let authorID = message["author"] as? String,
              let currentUserID = loggedInUserID else {
            return false
        }
        return authorID == currentUserID
    }

    var body: some View {
        VStack(alignment: .leading) {
            if let title = message["title"] as? String {
                Text(title)
                    .font(.headline)
            }
            if let messageText = message["message"] as? String {
                Text(messageText)
                    .font(.body)
            }
            HStack {
                if let displayName = message["display_name"] as? String,
                   let dateString = message["date"] as? String {
                    Text("By: \(displayName) @ \(dateString)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer() // Push the button to the right

                // Show the remove button only for the logged-in user's messages
                if isMyMessage, let messageID = message["id"] as? String {
                    Button("Remove") {
                        onDelete(messageID)
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }

            // Debugging Text
            Text("authorID: \((message["author"] as? String) ?? "N/A"); currentUserID: \(loggedInUserID ?? "N/A"); matches: \(isMyMessage ? "True" : "False")")
                .font(.caption2)
                .foregroundColor(.secondary)


            if let imageUrlString = message["image"] as? String, !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) {
                if isLoadingImage {
                    ProgressView()
                        .frame(width: 100, height: 100) // Placeholder size
                } else if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                } else {
                    // Optional: Display a placeholder if image loading fails or image not found
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .onAppear {
            loadImage()
        }
         // Add an identifier based on a unique property of the message
        .id(message["swiftuiID"] as? String ?? UUID().uuidString)
    }

    private func loadImage() {
        guard let imageUrlString = message["image"] as? String, !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) else { return }

        isLoadingImage = true

        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            DispatchQueue.main.async {
                isLoadingImage = false
                if let data = data, let uiImage = UIImage(data: data) {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

// Custom extension to convert message dictionary to a JSON string representation (still useful for debugging if needed)
extension Dictionary {
    var jsonString: String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: self, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else {
            return ""
        }
    }
}
