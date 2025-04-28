import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var token: String? = nil
    @State private var loginError: String? = nil
    @State private var fetchError: String? = nil
    @State private var isLoading: Bool = false
    @State private var messages: [[String: Any]] = [] // Changed to hold the parsed message array

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
                    // Use the JSON string representation of each message as the id
                    ForEach(messages, id: \.jsonString) { message in
                        VStack {
                            if let jsonString = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted),
                               let jsonStringOutput = String(data: jsonString, encoding: .utf8) {
                                TextEditor(text: .constant(jsonStringOutput))
                                    .padding()
                                    .frame(height: 200)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(10)
                                    .padding()
                                    .font(.system(.body, design: .monospaced))
                            }
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {  // Expecting an array of messages
                    DispatchQueue.main.async {
                        if let status = json.first?["status"] as? String, status != "success" {
                            self.fetchError = json.first?["message"] as? String ?? "Failed fetching messages"
                            self.messages = []
                        } else {
                            self.messages = json // Store the array of messages
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

// Custom extension to convert message dictionary to a JSON string representation
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
