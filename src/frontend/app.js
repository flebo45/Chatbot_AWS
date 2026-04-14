// Configuration
const API_GATEWAY_URL =
  "https://gn9ut4ypve.execute-api.eu-central-1.amazonaws.com/chat"; // We will fill this in next!
const USER_ID = "user_" + Math.random().toString(36).substring(2, 9); // Generate a random session ID
const USER_NAME = "Guest User";

// DOM Elements
const chatWindow = document.getElementById("chat-window");
const chatForm = document.getElementById("chat-form");
const messageInput = document.getElementById("message-input");
const sendButton = document.getElementById("send-button");
const displayUsername = document.getElementById("display-username");

// Avatars (Using DiceBear API for dynamic generated avatars)
const AI_AVATAR = "https://api.dicebear.com/7.x/bottts/svg?seed=ai";
const USER_AVATAR = `https://api.dicebear.com/7.x/adventurer/svg?seed=${USER_ID}`;

// Initialization
document.addEventListener("DOMContentLoaded", () => {
  displayUsername.textContent = USER_NAME;
});

// Event Listener for Form Submission
chatForm.addEventListener("submit", async (e) => {
  e.preventDefault();

  const message = messageInput.value.trim();
  if (!message) return;

  // 1. Instantly show user's message in the UI
  appendMessage("user", message);
  messageInput.value = "";

  // Disable input while waiting for AI
  messageInput.disabled = true;
  sendButton.disabled = true;

  // 2. Add a temporary "Typing..." indicator
  const typingId = appendTypingIndicator();

  try {
    // 3. Send data to your AWS Serverless Backend
    const response = await fetch(API_GATEWAY_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        user_id: USER_ID,
        message: message,
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();

    // 4. Remove typing indicator and show AI's actual reply
    removeTypingIndicator(typingId);
    appendMessage("ai", data.reply);
  } catch (error) {
    console.error("Error communicating with backend:", error);
    removeTypingIndicator(typingId);
    appendMessage(
      "ai",
      "⚠️ Sorry, I encountered a network error. Please try again.",
    );
  } finally {
    // Re-enable inputs
    messageInput.disabled = false;
    sendButton.disabled = false;
    messageInput.focus();
  }
});

// UI Helper Functions
function appendMessage(sender, text) {
  const isAI = sender === "ai";
  const avatar = isAI ? AI_AVATAR : USER_AVATAR;

  // Format timestamp nicely
  const timeString = new Date().toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });

  const messageWrapper = document.createElement("div");
  messageWrapper.classList.add("message-wrapper", sender);

  messageWrapper.innerHTML = `
        <img src="${avatar}" alt="${sender} avatar" class="avatar">
        <div class="message-content">
            <div class="message-bubble">${escapeHTML(text)}</div>
            <span class="timestamp">${timeString}</span>
        </div>
    `;

  chatWindow.appendChild(messageWrapper);
  scrollToBottom();
}

function appendTypingIndicator() {
  const id = "typing-" + Date.now();
  const wrapper = document.createElement("div");
  wrapper.classList.add("message-wrapper", "ai");
  wrapper.id = id;

  wrapper.innerHTML = `
        <img src="${AI_AVATAR}" alt="ai avatar" class="avatar">
        <div class="message-content">
            <div class="message-bubble"><em>typing...</em></div>
        </div>
    `;

  chatWindow.appendChild(wrapper);
  scrollToBottom();
  return id;
}

function removeTypingIndicator(id) {
  const el = document.getElementById(id);
  if (el) el.remove();
}

function scrollToBottom() {
  chatWindow.scrollTop = chatWindow.scrollHeight;
}

// Security: Prevent XSS attacks if the user tries to type HTML into the box
function escapeHTML(str) {
  return str.replace(
    /[&<>'"]/g,
    (tag) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "'": "&#39;",
        '"': "&quot;",
      })[tag],
  );
}
