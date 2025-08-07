import SwiftUI
import AppKit // Required for NSPasteboard (clipboard access)

// MARK: - Models and Helper Views

// ChatMessage model, now conforming to Codable
struct ChatMessage: Identifiable, Hashable, Codable {
    let id = UUID()
    var text: String
    var isUser: Bool
    var isDisplayed: Bool = false // Track if already shown
}

// View to animate word-by-word
struct TypingTextView: View {
    let fullText: String
    @State private var displayedWords: [String] = []
    @State private var currentIndex = 0

    var body: some View {
        Text(displayedWords.joined(separator: " "))
            .onAppear {
                let words = fullText.components(separatedBy: " ")
                Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { timer in
                    if currentIndex < words.count {
                        displayedWords.append(words[currentIndex])
                        currentIndex += 1
                    } else {
                        timer.invalidate()
                    }
                }
            }
    }
}

// Animated "Generating..." view
struct GeneratingDotsView: View {
    @State private var dotCount = 1
    let baseText = "Generating"

    var body: some View {
        Text("\(baseText)\(String(repeating: ".", count: dotCount))")
            .italic()
            .foregroundColor(.gray)
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                    dotCount = dotCount % 3 + 1
                }
            }
    }
}

// View for each chat message
struct MessageRowView: View {
    let message: ChatMessage
    @Binding var messages: [ChatMessage]

    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            } else {
                Group {
                    if message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.6)
                            GeneratingDotsView()
                        }
                    } else {
                        if message.isDisplayed {
                            Text(.init(message.text)) // Instantly show if already displayed
                        } else {
                            TypingTextView(fullText: message.text)
                                .onAppear {
                                    // Mark as displayed after animation starts
                                    if let index = messages.firstIndex(where: { $0.id == message.id }) {
                                        messages[index].isDisplayed = true
                                    }
                                }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                Spacer()
            }
        }
    }
}

// Example of appending a new message (defined but not currently called in the main flow)
func appendAIResponse(_ text: String, to messages: inout [ChatMessage]) {
    if let index = messages.lastIndex(where: { !$0.isUser && $0.text.isEmpty }) {
        messages[index] = ChatMessage(text: text, isUser: false, isDisplayed: false)
    }
}

// A PreferenceKey to store and pass the scroll view's offset.
struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


// MARK: - ChatView
// The main SwiftUI View for the chat interface.
struct ChatView: View {
    // MARK: - State Properties
    @State private var inputText = ""
    @AppStorage("savedMessages") private var savedMessagesData: Data = Data()
    @State private var messages: [ChatMessage] = []

    @State private var isAutoScrollEnabled = true
    @State private var scrollViewOffset: CGFloat = .zero

    @FocusState private var focused: Bool

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar for Copy and Clear buttons
            chatToolbar

            // ScrollViewReader allows programmatic scrolling.
            ScrollViewReader { proxy in
                chatHistoryView(proxy: proxy)
            }

            Divider()

            // Input field and Send button.
            chatInput
        }
        .frame(width: 460, height: 360)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
        .onAppear(perform: loadMessages)
    }

    // The toolbar is now in its own clean property.
    private var chatToolbar: some View {
        HStack {
            Button {
                clearMessages()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.leading)

            Spacer()

            Button {
                copyLastAIResponse()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.trailing)
        }
        .padding(.top, 8)
    }
    
    // The complex ScrollView broken out to solve the "unable to type-check" error.
    private func chatHistoryView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(messages) { msg in
                    MessageRowView(message: msg, messages: $messages)
                }
            }
            .padding(.vertical)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ViewOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .mask(
            LinearGradient(gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.05),
                .init(color: .black, location: 0.95),
                .init(color: .clear, location: 1)
            ]), startPoint: .top, endPoint: .bottom)
        )
        .mask(
            LinearGradient(gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.02),
                .init(color: .black, location: 0.98),
                .init(color: .clear, location: 1)
            ]), startPoint: .leading, endPoint: .trailing)
        )
        .onPreferenceChange(ViewOffsetKey.self) { newOffset in
            isAutoScrollEnabled = newOffset >= -50
        }
        .onChange(of: messages) { _ in
            if isAutoScrollEnabled, let last = messages.last {
                withAnimation {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
    
    // The input area is also in its own property for cleanliness.
    private var chatInput: some View {
        HStack {
            TextField("Ask me...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }
                .focused($focused)

            Button("Send") {
                sendMessage()
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear {
            focused = true
        }
        .onDisappear {
            focused = false
        }
        .padding()
    }
    
    // MARK: - Private Methods
    
    // Saves the current messages array to AppStorage.
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            savedMessagesData = encoded
        }
    }

    // Loads messages and marks them as displayed to prevent re-animation.
    private func loadMessages() {
        guard let decoded = try? JSONDecoder().decode([ChatMessage].self, from: savedMessagesData) else { return }

        self.messages = decoded.map { message in
            var mutableMessage = message
            mutableMessage.isDisplayed = true
            return mutableMessage
        }
    }

    // Handles sending a message (user input).
    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message.
        messages.append(ChatMessage(text: trimmed, isUser: true, isDisplayed: true)) // User messages are always displayed
        inputText = ""

        // Add an empty AI message placeholder to be filled by the streaming response.
        messages.append(ChatMessage(text: "", isUser: false))
        saveMessages() // Save after adding messages

        // Start a new Task to query Hack Club AI asynchronously.
        Task {
            await queryHackClubAI(trimmed)
        }
    }

    // Queries the Hack Club AI API for a response.
    func queryHackClubAI(_ input: String) async {
        guard let url = URL(string: "https://ai.hackclub.com/chat/completions") else {
            await MainActor.run {
                messages.append(ChatMessage(text: "Error: Invalid Hack Club AI URL.", isUser: false, isDisplayed: true))
                saveMessages()
            }
            return
        }

        let maxHistoryMessages = 10
        var messagesForAPI: [[String: String]] = []
        let historyForPrompt = messages.suffix(maxHistoryMessages)

        for message in historyForPrompt {
            if !message.text.isEmpty || message.isUser {
                messagesForAPI.append([
                    "role": message.isUser ? "user" : "assistant",
                    "content": message.text
                ])
            }
        }

        let systemPrompt = "You are a serious, professional, and factual assistant. Always use markdown to format your reponses, but you can only use **bold**, *italic* and [link](url) synthax. You may not use any other in any circumstances. Headers are also very stricly off limits. You may only use bold, italic, and link synthax. If you use any formatting besides a link, bold, or italic, rewrite the response. If you need to add emphasis use bolding and italic instead."
        
        // Assembling the final request body
        let body: [String: Any] = [
            "messages": [["role": "system", "content": systemPrompt]] + messagesForAPI,
            "stream": false
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw URLError(.cannotParseResponse)
            }

            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let messageDict = firstChoice["message"] as? [String: Any],
               let content = messageDict["content"] as? String {

                let cleanedContent: String
                if let range = content.range(of: "</think>") {
                    cleanedContent = String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                await MainActor.run {
                    if let index = messages.lastIndex(where: { !$0.isUser && $0.text.isEmpty }) {
                        // Update the placeholder with the response, isDisplayed will trigger animation
                        messages[index] = ChatMessage(text: cleanedContent, isUser: false, isDisplayed: false)
                    } else {
                        messages.append(ChatMessage(text: cleanedContent, isUser: false, isDisplayed: false))
                    }
                    saveMessages()
                }

            } else {
                throw URLError(.badServerResponse)
            }

        } catch {
            await MainActor.run {
                if let index = messages.lastIndex(where: { !$0.isUser && $0.text.isEmpty }) {
                    messages[index] = ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false, isDisplayed: true)
                } else {
                    messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false, isDisplayed: true))
                }
                saveMessages()
                print("❌ Error during request: \(error)")
            }
        }
    }

    // Function to copy only the last AI response to the pasteboard
    private func copyLastAIResponse() {
        if let lastAIMessage = messages.last(where: { !$0.isUser && !$0.text.isEmpty }) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lastAIMessage.text, forType: .string)
            print("Copied last AI response to clipboard.")
        } else {
            print("No AI response found to copy.")
        }
    }

    // Function to clear all messages
    private func clearMessages() {
        withAnimation(.easeOut(duration: 0.3)) {
            messages = []
        }
        savedMessagesData = Data()
        print("All messages cleared.")
    }
}
