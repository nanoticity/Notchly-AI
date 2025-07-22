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
                Text(message.text)
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

        // Start a new Task to query Ollama asynchronously.
        Task {
            await queryOllama(trimmed) // Pass the latest input for context building
        }
    }

    // Queries the Ollama API for a response, handling streaming.
    func queryOllama(_ input: String) async {
        // Ensure the URL is valid.
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else {
            await MainActor.run {
                messages.append(ChatMessage(text: "Error: Invalid Ollama URL.", isUser: false))
                saveMessages()
            }
            return
        }

        // Define the maximum number of messages to include in the context.
        // Adjust this value based on desired context length vs. response time.
        let maxHistoryMessages = 10 // Example: Keep the last 10 messages (5 user, 5 AI)

        // Construct the full conversation history for the prompt
        var fullPrompt = ""
        // Get the relevant subset of messages for context
        let historyForPrompt = messages.suffix(maxHistoryMessages)

        for message in historyForPrompt {
            // Only include messages that are not the current empty AI placeholder
            if message.text != "" || message.isUser {
                fullPrompt += message.isUser ? "User: \(message.text)\n" : "AI: \(message.text)\n"
            }
        }
        // Add a clear indicator for the AI's turn to respond
        fullPrompt += "AI:"
        
        print("Full prompt sent to Ollama:\n\(fullPrompt)") // Debug print: Show the full prompt

        // Prepare the request body.
        let body: [String: Any] = [
            "model": "llama3",
            "prompt": fullPrompt, // Use the full conversation history as the prompt
            "stream": true // Crucial for streaming responses.
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            // Serialize the body to JSON data.
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            // Perform the network request and get a byte stream.
            let (bytes, _) = try await URLSession.shared.bytes(for: request)

            var responseText = "" // Accumulate the streamed response.
            
            // Iterate over the lines of the byte stream.
            // This loop will process each chunk of the streamed response.
            for try await line in bytes.lines {
                print("Received line: \(line)") // Debug print: Show raw line from stream
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Parsed JSON: \(json)") // Debug print: Show parsed JSON dictionary
                    
                    // Extract the 'response' part from the JSON.
                    if let responseChunk = json["response"] as? String {
                        responseText += responseChunk // Append to the full response.
                        print("Appending response chunk: '\(responseChunk)'") // Debug print: Show extracted chunk
                        
                        // Update the UI on the MainActor.
                        await MainActor.run {
                            // Find the last message (which should be the AI placeholder)
                            // and update its text.
                            if var lastMessage = messages.last, !lastMessage.isUser {
                                // Update the existing AI message.
                                messages[messages.count - 1] = ChatMessage(text: responseText, isUser: false)
                                print("UI updated with text: '\(responseText)'") // Debug print: Show current accumulated text
                                // IMPORTANT: saveMessages() is NOT called here.
                                // It will be called once at the end of the stream.
                            }
                        }
                    }
                    
                    // Check if the stream is done.
                    if let done = json["done"] as? Bool, done {
                        print("Stream finished.") // Debug print: Indicate end of stream
                        break // Exit the loop if the response is complete.
                    }
                } else {
                    print("Failed to parse line as JSON: '\(line)'") // Debug print: Log malformed lines
                }
            }
            // After the streaming is complete (or breaks), save the final state.
            await MainActor.run {
                saveMessages() // Save messages only once after the full response is received.
                print("Final messages saved.") // Debug print: Confirm final save
            }
        } catch {
            // Handle any errors during the request or streaming.
            await MainActor.run {
                messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", isUser: false))
                saveMessages() // Save error message.
                print("Error during streaming: \(error.localizedDescription)") // Debug print: Log error
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
