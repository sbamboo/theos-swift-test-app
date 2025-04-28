import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var token: String? = nil
    @State private var loginError: String? = nil
    @State private var fetchError: String? = nil
    @State private var isLoading: Bool = false
    @State private var rawMessages: String = ""

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
                    Text(rawMessages)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding()
                        .font(.system(.body, design: .monospaced))
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
                self.rawMessages = ""
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
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async {
                        if let status = json["status"] as? String, status != "success" {
                            self.fetchError = json["message"] as? String ?? "Failed fetching messages"
                            self.rawMessages = ""
                        } else {
                            if let rawString = String(data: data, encoding: .utf8) {
                                self.rawMessages = rawString
                            } else {
                                self.rawMessages = "Failed to decode raw JSON"
                            }
                        }
                    }
                } else if let rawString = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.rawMessages = rawString
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
