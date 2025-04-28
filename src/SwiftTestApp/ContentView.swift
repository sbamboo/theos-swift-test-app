import SwiftUI

struct ContentView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var token: String? = nil
    @State private var loginError: String? = nil
    @State private var isAdmin: Bool = false
    @State private var userId: Int? = nil
    @State private var messages: [Message] = []
    @State private var isLoading: Bool = false

    struct Message: Identifiable, Codable {
        let id: Int
        let display_name: String
        let title: String
        let message: String
        let image: String
        let date: String
        let author: Int
    }

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

            if isLoading {
                ProgressView()
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(messages) { msg in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(msg.title)
                                    .font(.headline)

                                Text(msg.message)
                                    .font(.body)

                                Text("By: \(msg.display_name) @ \(msg.date)")
                                    .font(.footnote)
                                    .foregroundColor(.gray)

                                if !msg.image.isEmpty, let url = URL(string: msg.image) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxWidth: .infinity)
                                        case .failure:
                                            Image(systemName: "photo")
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
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
                            self.token = json["token"] as? String
                            self.isAdmin = (json["admin"] as? Bool) ?? false
                            self.userId = json["id"] as? Int
                            self.loginError = nil
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

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.token = nil
                self.messages = []
                self.username = ""
                self.password = ""
            }
        }.resume()
    }

    func fetchMessages() {
        guard let token = token, let url = URL(string: "https://conversa-api.ntigskovde.se/conversa.php?getAll&token=\(token)") else { return }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let data = data {
                if let jsonArray = try? JSONDecoder().decode([Message].self, from: data) {
                    DispatchQueue.main.async {
                        self.messages = jsonArray
                    }
                } else if let rawJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let messagesArray = rawJson["messages"] as? [[String: Any]] {
                    let decoded = messagesArray.compactMap { dict -> Message? in
                        guard let id = Int("\(dict["id"] ?? "")"),
                              let displayName = dict["display_name"] as? String,
                              let title = dict["title"] as? String,
                              let message = dict["message"] as? String,
                              let image = dict["image"] as? String,
                              let date = dict["date"] as? String,
                              let author = Int("\(dict["author"] ?? "")") else {
                            return nil
                        }
                        return Message(id: id, display_name: displayName, title: title, message: message, image: image, date: date, author: author)
                    }

                    DispatchQueue.main.async {
                        self.messages = decoded
                    }
                } else {
                    print("Failed to decode messages")
                }
            }
        }.resume()
    }
}
