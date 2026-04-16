"use client";

import { useState, useCallback, useEffect } from "react";
import {
  ChatSidebar,
  ChatHeader,
  ChatInput,
  MessageList,
  type Message,
} from "@/components/chat";

// 1. IDENTITY PERSISTENCE
// Get the ID from localStorage, or create a new one if it's their first time here.
const getOrCreateUserId = () => {
  let userId = localStorage.getItem("user_id");
  if (!userId) {
    userId = "user_" + Math.random().toString(36).substring(2, 9);
    localStorage.setItem("user_id", userId);
  }
  return userId;
};

const USER_ID = getOrCreateUserId();
// Ensure you have the stage name (like /production/chat) if your API GW requires it!
const API_URL =
  "https://nibbyexgcf.execute-api.eu-central-1.amazonaws.com/production/chat";

export default function App() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  // Using a single chat session for now, based on your activeChatId state
  const [activeChatId, setActiveChatId] = useState<string>("1");
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);

  // 2. THE HYDRATION HOOK (GET Request)
  // This runs automatically when the app loads or when you change activeChatId
  useEffect(() => {
    const fetchHistory = async () => {
      setIsLoadingHistory(true);

      try {
        const response = await fetch(`${API_URL}?user_id=${USER_ID}`, {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
          },
        });

        if (!response.ok) throw new Error("Failed to fetch history");

        const data = await response.json();
        const historyArray = data.chat_history || [];

        if (historyArray.length > 0) {
          // Map DynamoDB "turns" into separate "user" and "assistant" messages
          const chronologicalHistory = [...historyArray].reverse();
          const formattedMessages: Message[] = chronologicalHistory.flatMap(
            (row: any, index: number) => {
              const msgDate = row.timestamp
                ? new Date(row.timestamp)
                : new Date();
              return [
                {
                  id: `user-${index}`,
                  role: "user",
                  content: row.user_message,
                  timestamp: msgDate,
                },
                {
                  id: `ai-${index}`,
                  role: "assistant",
                  content: row.ai_response,
                  timestamp: new Date(msgDate.getTime() + 1),
                },
              ];
            },
          );
          setMessages(formattedMessages);
        } else {
          // If empty chat, show the greeting bubble
          setMessages([
            {
              id: "welcome",
              role: "assistant",
              content:
                "Hello! I am your Serverless AI Architect. How can I help you today?",
              timestamp: new Date(),
            },
          ]);
        }
      } catch (error) {
        console.error("Error fetching history:", error);
        setMessages([
          {
            id: "error",
            role: "assistant",
            content: "⚠️ Could not connect to AWS to load chat history.",
            timestamp: new Date(),
          },
        ]);
      } finally {
        setIsLoadingHistory(false);
      }
    };

    fetchHistory();
  }, [activeChatId]);

  // 3. SEND MESSAGE LOGIC (POST Request)
  const handleSendMessage = useCallback(async () => {
    if (!inputValue.trim()) return;

    const userText = inputValue.trim();

    // Show user message immediately (UI sets role: "user" -> aligns Right)
    const userMessage: Message = {
      id: Date.now().toString(),
      role: "user",
      content: userText,
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInputValue("");
    setIsTyping(true);

    try {
      const response = await fetch(API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id: USER_ID,
          message: userText,
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      // Show AI message (UI sets role: "assistant" -> aligns Left)
      const aiMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: "assistant",
        content: data.reply, // Adjust this if your POST lambda returns something else!
        timestamp: new Date(),
      };

      setMessages((prev) => [...prev, aiMessage]);
    } catch (error) {
      console.error("Error communicating with backend:", error);
      setMessages((prev) => [
        ...prev,
        {
          id: (Date.now() + 1).toString(),
          role: "assistant",
          content: "⚠️ Connection to AWS POST endpoint failed.",
          timestamp: new Date(),
        },
      ]);
    } finally {
      setIsTyping(false);
    }
  }, [inputValue, activeChatId]);

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar hidden for now as per your code */}

      <main className="flex flex-1 flex-col overflow-hidden">
        <ChatHeader modelName="Nova AI" isOnline={true} />

        {isLoadingHistory ? (
          <div className="flex flex-1 items-center justify-center text-muted-foreground">
            Loading your conversation from AWS...
          </div>
        ) : (
          <MessageList messages={messages} isTyping={isTyping} />
        )}

        <ChatInput
          value={inputValue}
          onChange={setInputValue}
          onSubmit={handleSendMessage}
          isLoading={isTyping || isLoadingHistory}
        />
      </main>
    </div>
  );
}
