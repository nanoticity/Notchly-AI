import SwiftUI
import AppKit
import MarkdownUI

// MARK: - Models and Helper Views

// ChatMessage model, now with a new property for animation state
struct ChatMessage: Identifiable, Hashable, Codable {
    var id = UUID()
    var text: String
    var isUser: Bool
    var isAnimating: Bool = false
    var isDisplayed: Bool = false
}

// View to animate word-by-word
struct TypingTextView: View {
    let fullText: String
    @Binding var isAnimating: Bool // Now a binding to control the state
    @State private var displayedWords: [String] = []
    @State private var currentIndex = 0
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        Markdown(displayedWords.joined(separator: " "))
            .onReceive(timer) { _ in
                let words = fullText.components(separatedBy: " ")
                if currentIndex < words.count {
                    displayedWords.append(words[currentIndex])
                    currentIndex += 1
                } else {
                    timer.upstream.connect().cancel()
                    isAnimating = false // Stop animating when done
                }
            }
            .onAppear {
                // Initialize the displayed words to an empty array so the animation starts from scratch
                displayedWords = []
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
    @Binding var message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            // AI Message
            if !message.isUser {
                Group {
                    if message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 8) {
                            GeneratingDotsView()
                        }
                    } else if message.isAnimating {
                        TypingTextView(fullText: message.text, isAnimating: $message.isAnimating)
                    } else {
                        Markdown(message.text)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                // Add padding on the left side
                .padding(.leading, 15)
                Spacer()
            }
            // User Message
            else {
                Spacer()
                Text(message.text)
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    // Add padding on the right side
                    .padding(.trailing, 15)
            }
        }
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
struct ChatView: View {
    @State private var inputText = ""
    @AppStorage("savedMessages") private var savedMessagesData: Data = Data()
    @State private var messages: [ChatMessage] = []
    @State private var isAutoScrollEnabled = true
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            
            ScrollViewReader { proxy in
                chatHistoryView(proxy: proxy)
            }

            Divider()
            chatInput
        }
        .frame(width: 460, height: 360)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
        .onAppear(perform: loadMessages)
    }
    
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
    
    private func chatHistoryView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                // Binding to each message to allow it to be mutated
                ForEach($messages) { $msg in
                    MessageRowView(message: $msg)
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
    
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            savedMessagesData = encoded
        }
    }

    private func loadMessages() {
        guard let decoded = try? JSONDecoder().decode([ChatMessage].self, from: savedMessagesData) else { return }
        self.messages = decoded.map { message in
            var mutableMessage = message
            mutableMessage.isDisplayed = true
            mutableMessage.isAnimating = false
            return mutableMessage
        }
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(text: trimmed, isUser: true, isAnimating: false, isDisplayed: true))
        inputText = ""

        let placeholderMessage = ChatMessage(text: "", isUser: false, isAnimating: true, isDisplayed: false)
        messages.append(placeholderMessage)

        saveMessages()

        Task {
            await queryOpenAI(trimmed, placeholderID: placeholderMessage.id)
        }
    }

    private static let openAIModel = "gpt-4o-mini"

    func queryOpenAI(_ input: String, placeholderID: UUID) async {
        let apiKey = (UserDefaults.standard.string(forKey: "openai_api_key") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty, let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            await failPlaceholder(placeholderID, message: "Error: No OpenAI API key configured. Please relaunch the app to set one up.")
            return
        }

        let maxHistoryMessages = 10
        var messagesForAPI: [[String: String]] = []
        let historyForAPI = messages.suffix(maxHistoryMessages)

        for message in historyForAPI {
            // Skip the empty assistant placeholder we just appended.
            if !message.isUser && message.text.isEmpty { continue }
            messagesForAPI.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.text
            ])
        }

        let body: [String: Any] = [
            "model": ChatView.openAIModel,
            "messages": messagesForAPI,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                await failPlaceholder(placeholderID, message: "Error: OpenAI returned status \(http.statusCode).")
                return
            }

            // Begin streaming display.
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
                    messages[index].isDisplayed = true
                    messages[index].isAnimating = false
                }
            }

            for try await line in bytes.lines {
                // SSE: ignore blanks and non-data lines.
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }
                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let chunk = delta["content"] as? String,
                      !chunk.isEmpty else {
                    continue
                }

                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
                        messages[index].text.append(chunk)
                    }
                }
            }

            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
                    messages[index].text = messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                saveMessages()
            }
        } catch {
            await failPlaceholder(placeholderID, message: "Error: \(error.localizedDescription)")
            print("❌ Error during request: \(error)")
        }
    }

    @MainActor
    private func failPlaceholder(_ placeholderID: UUID, message: String) {
        if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
            messages[index] = ChatMessage(text: message, isUser: false, isAnimating: false, isDisplayed: true)
        }
        saveMessages()
    }

    private func copyLastAIResponse() {
        if let lastAIMessage = messages.last(where: { !$0.isUser && !$0.text.isEmpty }) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lastAIMessage.text, forType: .string)
            print("Copied last AI response to clipboard.")
        } else {
            print("No AI response found to copy.")
        }
    }

    private func clearMessages() {
        withAnimation(.easeOut(duration: 0.3)) {
            messages = []
        }
        savedMessagesData = Data()
        print("All messages cleared.")
    }
}
