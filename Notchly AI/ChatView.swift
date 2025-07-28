import SwiftUI
import AppKit // Required for NSPasteboard (clipboard access)

// MARK: - ChatMessage Model
// Represents a single message in the chat, conforming to Identifiable, Codable, and Equatable.
struct ChatMessage: Identifiable, Codable, Equatable {
    let id = UUID() // Unique identifier for each message.
    let text: String // The content of the message.
    let isUser: Bool // True if the message is from the user, false if from the AI.
}

// MARK: - ViewOffsetKey
// A PreferenceKey to capture the scroll view's content offset.
struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - MessageRowView
// A separate view for displaying a single chat message.
// This helps to simplify the main ChatView's body and can improve compile times.
struct MessageRowView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer() // Pushes user message to the right.
                Text(message.text)
                    .padding()
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(8)
                    .textSelection(.enabled) // Make text selectable
            } else {
                Text(.init(message.text))
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .textSelection(.enabled) // Make text selectable
                Spacer() // Pushes AI message to the left.
            }
        }
        .padding(.horizontal) // Horizontal padding for each message row.
        .id(message.id) // Assign ID for ScrollViewReader to scroll to.
    }
}

// MARK: - ChatView
// The main SwiftUI View for the chat interface.
struct ChatView: View {
    @State private var inputText = "" // State for the text input field.
    // @AppStorage for persistent storage of messages.
    // Note: For very large chat histories, consider a more robust persistence solution
    // like Core Data or Realm, as AppStorage is best for smaller data sets.
    @AppStorage("savedMessages") private var savedMessagesData: Data = Data()
    @State private var messages: [ChatMessage] = [] // Array to hold all chat messages.
    
    @State private var isAutoScrollEnabled = true // Controls automatic scrolling to the bottom.
    @State private var scrollViewOffset: CGFloat = .zero // State to hold the scroll view's offset.

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Add a toolbar or header for the "Copy Last AI Response" and "Clear Chat" buttons
            HStack {
                Button {
                    clearMessages() // Call the new clear function
                } label: {
                    Image(systemName: "trash") // Use a system icon for clear
                        .font(.title3) // Adjust icon size
                        .foregroundColor(.red) // Make it red to signify deletion
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.leading) // Add padding to the left

                Spacer() // Pushes buttons to the right and left

                Button {
                    copyLastAIResponse() // Call the copy function
                } label: {
                    Image(systemName: "doc.on.doc") // Use a system icon for copy
                        .font(.title3) // Adjust icon size
                        .foregroundColor(.primary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .padding(.trailing)
            }
            .padding(.top, 8) // Add some padding at the top

            // ScrollViewReader allows programmatic scrolling.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        // Display each message using the new MessageRowView.
                        ForEach(messages) { msg in
                            MessageRowView(message: msg)
                        }
                    }
                    .padding(.vertical) // Vertical padding for the VStack of messages.
                    // Use GeometryReader to publish the scroll view's content offset
                    // via the custom PreferenceKey.
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ViewOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "scroll") // Define coordinate space for GeometryReader.
                // Apply a gradient mask to the scroll view to create a fade effect at the edges.
                .mask(
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),     // Top fade
                        .init(color: .black, location: 0.05),  // Start opaque after 5%
                        .init(color: .black, location: 0.95),  // End opaque before 95%
                        .init(color: .clear, location: 1)      // Bottom fade
                    ]), startPoint: .top, endPoint: .bottom)
                    .mask(
                        LinearGradient(gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),     // Left fade
                            .init(color: .black, location: 0.02),  // Start opaque after 2%
                            .init(color: .black, location: 0.98),  // End opaque before 98%
                            .init(color: .clear, location: 1)      // Right fade
                        ]), startPoint: .leading, endPoint: .trailing)
                    )
                )
                // React to changes in the scroll view's offset.
                .onPreferenceChange(ViewOffsetKey.self) { newOffset in
                    // If user scrolls up more than 50 pts (offset becomes less than -50), disable auto scroll.
                    isAutoScrollEnabled = newOffset >= -50
                }
                // React to changes in the messages array for auto-scrolling.
                .onChange(of: messages) { _ in
                    if isAutoScrollEnabled, let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom) // Scroll to the latest message.
                        }
                    }
                }
            }
            
            Divider() // Separator between chat messages and input field.

            // Input field and Send button.
            HStack {
                TextField("Ask me...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage() // Send message on pressing return key.
                    }

                Button("Send") {
                    sendMessage() // Send message on button tap.
                }
                // Disable send button if input text is empty or just whitespace.
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding() // Padding for the input and button HStack.
        }
        // Frame and styling for the entire chat view.
        .frame(width: 460, height: 360)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
        // Load messages when the view appears.
        .onAppear(perform: loadMessages)
    }

    // MARK: - Private Methods
    
    // Saves the current messages array to AppStorage.
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            savedMessagesData = encoded
        }
    }

    // Loads messages from AppStorage into the messages array.
    private func loadMessages() {
        if let decoded = try? JSONDecoder().decode([ChatMessage].self, from: savedMessagesData) {
            messages = decoded
        }
    }

    // Handles sending a message (user input).
    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return } // Do nothing if input is empty.

        // Add user message.
        messages.append(ChatMessage(text: trimmed, isUser: true))
        saveMessages() // Save messages after adding user message.
        inputText = "" // Clear the input field.

        // Add an empty AI message placeholder to be filled by the streaming response.
        messages.append(ChatMessage(text: "", isUser: false))
        saveMessages() // Save messages after adding AI placeholder.

        // Start a new Task to query Hack Club AI asynchronously.
        Task {
            await queryHackClubAI(trimmed)
        }
    }

    // Queries the Hack Club AI API for a response, handling streaming.
    func queryHackClubAI(_ input: String) async {
        guard let url = URL(string: "https://ai.hackclub.com/chat/completions") else {
            await MainActor.run {
                messages.append(ChatMessage(text: "Error: Invalid Hack Club AI URL.", isUser: false))
                saveMessages()
            }
            return
        }

        let maxHistoryMessages = 10

        var messagesForAPI: [[String: String]] = []
        let historyForPrompt = messages.suffix(maxHistoryMessages)

        for message in historyForPrompt {
            if message.text != "" || message.isUser {
                messagesForAPI.append([
                    "role": message.isUser ? "user" : "assistant",
                    "content": message.text
                ])
            }
        }

        messagesForAPI.append([
            "role": "system",
            "content": "You are a helpful AI assistant. Always use markdown to format your reponses, but you can only use **bold**, *italic* and [link](url) synthax. You may not use any other in any circumstances. Absolutely none of these!!! Headers are also stricly off limits."
        ])

        messagesForAPI.append([
            "role": "user",
            "content": input
        ])

        print("Messages sent to Hack Club AI:\n\(messagesForAPI)")

        let body: [String: Any] = [
            "messages": messagesForAPI,
            "stream": true
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (bytes, _) = try await URLSession.shared.bytes(for: request)

            var responseText = ""          // Accumulate the entire streamed response
            var startedStreaming = false   // Track if </think> has appeared

            for try await line in bytes.lines {
                print("Received line: \(line)")

                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    print("Parsed JSON: \(json)")

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first {

                        if let delta = firstChoice["delta"] as? [String: Any],
                           let contentChunk = delta["content"] as? String {

                            responseText += contentChunk

                            if !startedStreaming {
                                if let range = responseText.range(of: "</think>") {
                                    startedStreaming = true

                                    // Text after </think>
                                    let afterThink = responseText[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)

                                    await MainActor.run {
                                        if var lastMessage = messages.last, !lastMessage.isUser {
                                            messages[messages.count - 1] = ChatMessage(text: String(afterThink), isUser: false)
                                        }
                                    }
                                } else {
                                    // Haven't reached </think> yet - do not update UI
                                    continue
                                }
                            } else {
                                // Already started streaming after </think>, update UI normally with only the text after </think>
                                await MainActor.run {
                                    if var lastMessage = messages.last, !lastMessage.isUser {
                                        if let range = responseText.range(of: """
</think>


""") {
                                            let afterThink = responseText[range.upperBound...]
                                            messages[messages.count - 1] = ChatMessage(text: String(afterThink), isUser: false)
                                        } else {
                                            // Defensive fallback
                                            messages[messages.count - 1] = ChatMessage(text: responseText, isUser: false)
                                        }
                                    }
                                }
                            }
                        } else if let messageDict = firstChoice["message"] as? [String: Any],
                                  let contentChunk = messageDict["content"] as? String {
                            // Handle non-streaming full content
                            responseText = contentChunk
                            await MainActor.run {
                                if var lastMessage = messages.last, !lastMessage.isUser {
                                    messages[messages.count - 1] = ChatMessage(text: responseText, isUser: false)
                                }
                            }
                        }
                    }

                    if let done = json["done"] as? Bool, done {
                        print("Stream finished.")
                        break
                    }
                } else {
                    print("Failed to parse line as JSON: '\(line)'")
                }
            }

            await MainActor.run {
                saveMessages()
                print("Final messages saved.")
            }

        } catch {
            await MainActor.run {
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                saveMessages()
                print("Error during streaming: \(error.localizedDescription)")
            }
        }
    }

    // Function to copy only the last AI response to the pasteboard
    private func copyLastAIResponse() {
        // Find the last AI message
        if let lastAIMessage = messages.last(where: { !$0.isUser }) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lastAIMessage.text, forType: .string)
            print("Copied last AI response to clipboard: '\(lastAIMessage.text)'")
        } else {
            print("No AI response found to copy.")
        }
    }

    // Function to clear all messages and AI memory
    private func clearMessages() {
        withAnimation(.easeOut(duration: 0.3)) { // Animate the clearing of messages
            messages = [] // Clear the messages array
        }
        savedMessagesData = Data() // Clear saved messages from AppStorage
        print("All messages and AI memory cleared.")
        // The AI's "memory" is the conversation history sent in the prompt.
        // By clearing 'messages', the next prompt will start fresh.
    }
}
