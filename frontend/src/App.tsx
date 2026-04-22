"use client";

import { useState, useCallback, useEffect } from "react";
import {
  ChatHeader,
  ChatInput,
  MessageList,
  type Message,
} from "@/components/chat";

import { flushSync } from "react-dom";

// 1. IDENTITY PERSISTENCE
const getOrCreateUserId = () => {
  let userId = localStorage.getItem("user_id");
  if (!userId) {
    userId = "user_" + Math.random().toString(36).substring(2, 9);
    localStorage.setItem("user_id", userId);
  }
  return userId;
};

const USER_ID = getOrCreateUserId();

// PASTE YOUR TERRAFORM OUTPUT URL HERE (Must be https://.../chat)
const API_URL =
  "https://iorg3jsrs1.execute-api.eu-central-1.amazonaws.com/production/chat";

const STREAM_URL =
  "https://actyrbqpxlhhztqoy7p2nmydbm0uyrax.lambda-url.eu-central-1.on.aws/";

export default function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);

  // 2. HYDRATION HOOK (GET Request for Chat History)
  useEffect(() => {
    const fetchHistory = async () => {
      setIsLoadingHistory(true);
      try {
        const response = await fetch(`${API_URL}?user_id=${USER_ID}`, {
          method: "GET",
          headers: { "Content-Type": "application/json" },
        });

        if (!response.ok) throw new Error("Failed to fetch history");

        const data = await response.json();
        const historyArray = data.chat_history || [];

        if (historyArray.length > 0) {
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
      } finally {
        setIsLoadingHistory(false);
      }
    };

    fetchHistory();
  }, []);

  // 3. SEND MESSAGE LOGIC (POST Request with HTTP Streaming)
  const handleSendMessage = useCallback(async () => {
    if (!inputValue.trim()) return;

    const userText = inputValue.trim();

    // 1. Show user message immediately
    const userMessage: Message = {
      id: Date.now().toString(),
      role: "user",
      content: userText,
      timestamp: new Date(),
    };

    // 2. Create an empty placeholder message for the AI immediately
    const aiMessageId = (Date.now() + 1).toString();
    const initialAiMessage: Message = {
      id: aiMessageId,
      role: "assistant",
      content: "",
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage, initialAiMessage]);
    setInputValue("");
    setIsTyping(true);

    try {
      const response = await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: USER_ID,
          message: userText,
        }),
      });

      if (!response.ok || !response.body) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      // 3. Attach a reader to the incoming HTTP data stream
      const reader = response.body.getReader();
      const decoder = new TextDecoder("utf-8");
      let aiFullText = "";

      setIsTyping(false); // AI started responding!

      // 4. The Streaming Loop
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        // Decode the raw bytes into a string chunk
        const chunk = decoder.decode(value, { stream: true });
        aiFullText += chunk;

        // Instantly update the UI with the new text
        flushSync(() => {
          setMessages((prev) =>
            prev.map((msg) =>
              msg.id === aiMessageId
                ? { ...msg, content: aiFullText.trimStart() }
                : msg,
            ),
          );
        });
      }
    } catch (error) {
      console.error("Error communicating with backend:", error);
      setMessages((prev) =>
        prev.map((msg) =>
          msg.id === aiMessageId
            ? { ...msg, content: "⚠️ Connection to AWS POST endpoint failed." }
            : msg,
        ),
      );
    } finally {
      setIsTyping(false);
    }
  }, [inputValue]);

  return (
    <div className="flex h-screen bg-background">
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
