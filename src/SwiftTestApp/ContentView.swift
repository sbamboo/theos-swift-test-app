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

    // New state variables for the input fields
    @State private var newMessageTitle: String = ""
    @State private var newMessageText: String = ""
    @State private var newMessageImageUrl: String = ""
    @State private var sendMessageError: String? = nil // State for new message errors

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
                    .padding(.horizontal) // Add horizontal padding for better layout
            }

            if let error = deleteMessageError {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.horizontal) // Add horizontal padding
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

            // New Post Section
            VStack(spacing: 8) {
                if let error = sendMessageError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                TextField("Title", text: $newMessageTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextField("Message", text: $newMessageText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextField("Optional: Image URL", text: $newMessageImageUrl)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)

                Button("Send Post") {
                    sendMessage()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.bottom) // Add some space at the bottom
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
                                // Attempt to extract and set the logged-in user's ID
                                if let userID = json["id"] as? String {
                                    self.loggedInUserID = userID
                                } else if let userID = json["id"] as? Int {
                                    self.loggedInUserID = String(userID)
                                } else {
                                    // If ID is missing or not a String/Int, treat as login failure
                                    self.loginError = "Login failed: User ID missing or incorrect type in response."
                                    self.token = nil // Invalidate the token if ID is missing
                                    self.loggedInUserID = nil // Ensure loggedInUserID is nil
                                    return // Stop processing here as login failed
                                }

                                // If we successfully got the token and user ID
                                self.token = token
                                self.loginError = nil

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
                // Clear new message input fields and error
                self.newMessageTitle = ""
                self.newMessageText = ""
                self.newMessageImageUrl = ""
                self.sendMessageError = nil
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

    func sendMessage() {
        guard let token = token, let authorID = loggedInUserID else {
            self.sendMessageError = "Not logged in."
            return
        }

        guard let url = URL(string: "https://conversa-api.ntigskovde.se/conversa.php?token=\(token)") else {
            self.sendMessageError = "Invalid URL."
            return
        }

        // Basic validation
        guard !newMessageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.sendMessageError = "Title and Message cannot be empty."
            return
        }

        isLoading = true // Indicate that sending is in progress
        sendMessageError = nil // Clear previous errors

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messageData: [String: Any] = [
            "author": authorID,
            "title": newMessageTitle,
            "message": newMessageText
        ]

        if !newMessageImageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageData["image"] = newMessageImageUrl
        }

        let postData: [String: Any] = [
            "add": "1",
            "data": messageData
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: postData, options: [])
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.sendMessageError = "Failed to create request body: \(error.localizedDescription)"
            }
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false // Sending is complete (success or failure)
                if let error = error {
                    self.sendMessageError = "Network error sending message: \(error.localizedDescription)"
                    return
                }

                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let status = json["status"] as? String {
                    if status == "success" {
                        // Message sent successfully, clear the input fields and refresh messages
                        self.newMessageTitle = ""
                        self.newMessageText = ""
                        self.newMessageImageUrl = ""
                        self.sendMessageError = nil // Clear any success messages (though none are shown currently)
                        self.fetchMessages() // Refresh the message list
                    } else {
                        self.sendMessageError = json["message"] as? String ?? "Failed to send message."
                    }
                } else {
                    self.sendMessageError = "Failed to decode send message response."
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

            // Debugging Text (Optional: You might want to remove this in production)
//            Text("authorID: \((message["author"] as? String) ?? "N/A"); currentUserID: \(loggedInUserID ?? "N/A"); matches: \(isMyMessage ? "True" : "False")")
//                .font(.caption2)
//                .foregroundColor(.secondary)


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
