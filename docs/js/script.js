document.addEventListener('DOMContentLoaded', () => {
    const backgroundLiquid = document.querySelector('.background-liquid-gray');
    const macScreenFrame = document.querySelector('.mac-screen-frame');

    // NEW: Interactive AI Chat Elements
    const aiInput = document.getElementById('aiInput');
    const sendBtn = document.getElementById('sendBtn');
    const chatHistory = document.getElementById('chatHistory');
    const aiLoading = document.getElementById('aiLoading');

    // Page load elements staggered fade-in
    const animatableElements = document.querySelectorAll('.animatable-onload');
    let delay = 0;
    const delayIncrement = 150; // Milliseconds between each element's animation start

    animatableElements.forEach(element => {
        // Exclude the chat history from initial delay if you want it visible immediately
        // The individual messages inside chat history will still animate if they have animatable-onload
        if (!element.classList.contains('chat-history') && !element.closest('.chat-history')) {
            requestAnimationFrame(() => {
                element.style.setProperty('--animation-delay', `${delay}ms`);
                element.classList.add('loaded');
            });
            delay += delayIncrement;
        } else {
             // For chat history container itself, ensure it's visible without delay
             requestAnimationFrame(() => {
                element.classList.add('loaded');
             });
        }
    });

    // --- NEW: AI Chat Functionality ---
    const addMessage = (text, sender, isAIResponse = false) => {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('chat-message', `${sender}-message`);
        messageDiv.classList.add('animatable-onload'); // To animate new messages

        const textSpan = document.createElement('span');
        textSpan.classList.add('message-text');
        if (isAIResponse) {
            textSpan.classList.add('ai-response');
        }
        // Use innerHTML to allow for <br> tags if the AI response includes them
        textSpan.innerHTML = text;

        messageDiv.appendChild(textSpan);
        chatHistory.appendChild(messageDiv);

        // Animate the new message in
        requestAnimationFrame(() => {
            messageDiv.style.setProperty('--animation-delay', `0ms`); // Animate instantly
            messageDiv.classList.add('loaded');
        });


        // Scroll to the bottom of the chat history
        chatHistory.scrollTop = chatHistory.scrollHeight;
    };

    const sendMessage = async () => {
        const userQuery = aiInput.value.trim();
        if (!userQuery) return;

        addMessage(userQuery, 'user');
        aiInput.value = ''; // Clear input field
        aiInput.disabled = true; // Disable input while waiting
        sendBtn.disabled = true;
        aiLoading.classList.add('visible'); // Show loading dots

        try {
            // CORRECTED ENDPOINT HERE!
            const response = await fetch('https://ai.hackclub.com/chat/completions', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    messages: [{ role: 'user', content: userQuery }],
                    model: 'gpt-3.5-turbo', // You can try 'gpt-4' if available to Hack Club AI, or 'gemini-pro'
                    stream: false, // For simplicity, we'll get the full response at once
                }),
            });

            if (!response.ok) {
                const errorData = await response.json(); // Try to parse error data
                throw new Error(`API Error: ${response.status} ${response.statusText} - ${errorData.error || errorData.message || 'Unknown error'}`);
            }

            const data = await response.json();
            const aiResponseText = data.choices[0].message.content;

            addMessage(aiResponseText, 'ai', true); // Add AI response
        } catch (error) {
            console.error('Error fetching AI response:', error);
            addMessage(`Oops! There was an error getting a response. Please try again later. (${error.message || 'Network error'})`, 'ai', true);
        } finally {
            aiInput.disabled = false; // Re-enable input
            sendBtn.disabled = false;
            aiLoading.classList.remove('visible'); // Hide loading dots
            aiInput.focus(); // Focus input for next query
        }
    };

    // Event listeners for sending message
    sendBtn.addEventListener('click', sendMessage);
    aiInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            sendMessage();
        }
    });
    // --- END NEW: AI Chat Functionality ---


    // Subtle mouse parallax for the gray liquid background
    document.addEventListener('mousemove', (e) => {
        const x = (e.clientX / window.innerWidth - 0.5) * 20;
        const y = (e.clientY / window.innerHeight - 0.5) * 20;

        if (backgroundLiquid) {
            backgroundLiquid.style.transform = `translate(${x}px, ${y}px)`;
        }
    });

    // Animate app icon in notch on hover (simulating subtle activity)
    if (macScreenFrame) {
        const appIcon = macScreenFrame.querySelector('.app-icon-mac');
        const notchStatus = macScreenFrame.querySelector('.notch-status');
        let intervalId;

        macScreenFrame.addEventListener('mouseenter', () => {
            clearInterval(intervalId);
            appIcon.style.transition = 'transform 0.4s cubic-bezier(0.25, 0.46, 0.45, 0.94)';

            let pulseScale = 1;
            let growing = true;
            intervalId = setInterval(() => {
                if (growing) {
                    pulseScale += 0.02;
                    if (pulseScale >= 1.1) growing = false;
                } else {
                    pulseScale -= 0.02;
                    if (pulseScale <= 1) growing = true;
                }
                appIcon.style.transform = `scale(${pulseScale})`;
            }, 120);

            if (notchStatus) {
                notchStatus.textContent = 'Active';
            }
        });

        macScreenFrame.addEventListener('mouseleave', () => {
            clearInterval(intervalId);
            appIcon.style.transform = 'scale(1)';
            appIcon.style.transition = 'transform 0.3s ease-out';

            if (notchStatus) {
                notchStatus.textContent = 'Online';
            }
        });
    }

    // Overall subtle scale for all glass elements on hover
    const glassElements = document.querySelectorAll('.glass-nav, .glass-card, .glass-button, .feature-item');

    glassElements.forEach(el => {
        el.addEventListener('mouseenter', () => {
            el.style.transform = 'scale(1.005)';
        });

        el.addEventListener('mouseleave', () => {
            el.style.transform = 'scale(1)';
        });
    });
});