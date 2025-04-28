import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var token: String? = nil
    @State private var loginError: String? = nil
    @State private var fetchError: String? = nil
    @State private var isLoading: Bool = false
    @State private var messages: [[String: Any]] = []

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

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    LazyVStack { // Use LazyVStack for better performance with many items
                        ForEach(messages.indices, id: \.self) { index in
                            MessageRow(message: messages[index])
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
}

// A custom View to display each message
struct MessageRow: View {
    let message: [String: Any]
    @State private var image: UIImage? = nil
    @State private var isLoadingImage: Bool = false

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
            }

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

// No longer needed as we're using indices for ForEach and adding a unique ID
// extension Dictionary where Key == String, Value == Any {
//     var id: Int? {
//         self["id"] as? Int
//     }
// }

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
