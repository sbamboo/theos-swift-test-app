import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var token: String? = nil
    @State private var loginError: String? = nil
    @State private var fetchError: String? = nil
    @State private var rawJson: String? = nil  // Store raw JSON response for debugging purposes
    @State private var isLoading: Bool = false
    @State private var messages: [Message] = [] // Changed to hold parsed Message objects

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

            if let rawJson = rawJson {
                VStack {
                    Text("Raw JSON Response:")
                        .font(.headline)
                        .padding(.top)
                    ScrollView {
                        Text(rawJson)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                            .frame(height: 200)
                    }
                }
            }

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    // Display each message
                    ForEach(messages) { message in
                        VStack(spacing: 12) {
                            Text(message.title)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(message.message)
                                .font(.body)

                            Text("By: \(message.displayName) @ \(message.date)")
                                .font(.footnote)
                                .foregroundColor(.gray)

                            if !message.image.isEmpty, let imageUrl = URL(string: message.image) {
                                AsyncImage(url: imageUrl) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image.resizable().scaledToFit().frame(height: 200)
                                    case .failure:
                                        Text("Image failed to load")
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .cornerRadius(8)
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
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
        rawJson = nil  // Clear previous raw JSON response

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
            }

            if let data = data {
                // Try to convert the raw data into a string for debugging purposes
                let rawJsonString = String(data: data, encoding: .utf8)
                DispatchQueue.main.async {
                    self.rawJson = rawJsonString // Save the raw JSON string for debugging
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    DispatchQueue.main.async {
                        if let status = json.first?["status"] as? String, status != "success" {
                            self.fetchError = json.first?["message"] as? String ?? "Failed fetching messages"
                            self.messages = []
                        } else {
                            // Parse JSON into Message structs
                            self.messages = json.compactMap { Message(dictionary: $0) }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.fetchError = "Failed to decode messages. Raw JSON: \(rawJsonString ?? "No JSON available")"
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

// Message struct to represent a message
struct Message: Identifiable {
    var id: Int
    var displayName: String
    var title: String
    var message: String
    var image: String
    var date: String
    var author: Int

    // Initialize Message from dictionary
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? Int,
              let displayName = dictionary["display_name"] as? String,
              let title = dictionary["title"] as? String,
              let message = dictionary["message"] as? String,
              let image = dictionary["image"] as? String,
              let date = dictionary["date"] as? String,
              let author = dictionary["author"] as? Int else {
            return nil
        }
        self.id = id
        self.displayName = displayName
        self.title = title
        self.message = message
        self.image = image
        self.date = date
        self.author = author
    }
}
