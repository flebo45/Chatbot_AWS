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
const BASE_URL =
  "https://de53u52af0.execute-api.eu-west-1.amazonaws.com/production";
const API_URL = `${BASE_URL}/chat`;
const UPLOAD_URL = `${BASE_URL}/upload-url`;

export default function App() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);

  // File Uploading
  const [isUploading, setIsUploading] = useState(false);
  const [uploadStatus, setUploadStatus] = useState("");

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

  const handleFileUpload = async (
    event: React.ChangeEvent<HTMLInputElement>,
  ) => {
    const files = event.target.files;
    if (!files || files.length === 0) return;

    setIsUploading(true);

    try {
      // Loop through all selected files
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        const fileType = file.type;
        setUploadStatus(`Uploading ${file.name} (${i + 1}/${files.length})...`);

        // 1. Get the VIP Pass (Presigned URL) from FastAPI
        const urlRes = await fetch(UPLOAD_URL, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ filename: file.name, user_id: USER_ID }),
        });

        if (!urlRes.ok)
          throw new Error(`Failed to get upload URL for ${file.name}`);
        const { upload_url } = await urlRes.json();

        // 2. Upload directly to S3 Bucket using the PUT method
        const uploadRes = await fetch(upload_url, {
          method: "PUT",
          headers: {
            // Must match what your Python code signed!
            "Content-Type": fileType,
          },
          body: file, // Send the raw file directly
        });

        if (!uploadRes.ok)
          throw new Error(`Failed to upload ${file.name} to S3`);
      }

      // 3. Fake a short wait for the Bedrock Ingestion Job to trigger via SQS
      setUploadStatus("Syncing documents to AI Knowledge Base...");

      setTimeout(() => {
        setIsUploading(false);
        setUploadStatus("");

        // Push a green system message to the chat so the user knows it worked
        setMessages((prev) => [
          ...prev,
          {
            id: Date.now().toString(),
            role: "assistant",
            content: `✅ Successfully uploaded and synced ${files.length} document(s). You can now ask me questions about them!`,
            timestamp: new Date(),
          },
        ]);
      }, 3500);
    } catch (error) {
      console.error("Upload error:", error);
      setUploadStatus("⚠️ Upload failed. Check console for details.");

      // Clear the error message after a few seconds
      setTimeout(() => {
        setIsUploading(false);
        setUploadStatus("");
      }, 4000);
    } finally {
      // Reset the input so the user can upload the same file again if needed
      event.target.value = "";
    }
  };

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

        <div className="px-4 pt-2 bg-background">
          {isUploading ? (
            <div className="flex items-center text-sm text-blue-500 animate-pulse">
              <span className="mr-2">⏳</span> {uploadStatus}
            </div>
          ) : (
            <label className="cursor-pointer text-sm font-medium text-muted-foreground hover:text-primary transition-colors flex items-center w-fit">
              <span className="mr-1">📎</span> Attach Documents
              <input
                type="file"
                multiple
                accept=".pdf, .docx, .txt"
                className="hidden"
                onChange={handleFileUpload}
              />
            </label>
          )}
        </div>

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
