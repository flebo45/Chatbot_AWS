"use client";

import { useRef, useEffect } from "react";
// Notice we removed the ScrollArea import!
import { MessageBubble, type Message } from "./message-bubble";
import { TypingIndicator } from "./typing-indicator";
import { Sparkles } from "lucide-react";

interface MessageListProps {
  messages: Message[];
  isTyping?: boolean;
}

export function MessageList({ messages, isTyping = false }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // This now works perfectly because it's inside a native scrolling div
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isTyping]);

  if (messages.length === 0 && !isTyping) {
    return (
      <div className="flex flex-1 flex-col items-center justify-center gap-4 p-8 text-center min-h-0">
        <div className="flex size-16 items-center justify-center rounded-2xl bg-primary">
          <Sparkles className="size-8 text-primary-foreground" />
        </div>
        <div className="max-w-md space-y-2">
          <h2 className="text-xl font-semibold text-foreground">
            How can I help you today?
          </h2>
          <p className="text-sm text-muted-foreground">
            Start a conversation by typing a message below. I&apos;m here to
            assist you with any questions or tasks.
          </p>
        </div>
      </div>
    );
  }

  return (
    // THE FIX: Replaced <ScrollArea> with native flex-1 overflow-y-auto min-h-0
    <div className="flex-1 overflow-y-auto min-h-0 px-4">
      <div className="mx-auto max-w-3xl py-4">
        {messages.map((message) => (
          <MessageBubble key={message.id} message={message} />
        ))}
        {isTyping && <TypingIndicator />}

        {/* The Anchor point for the scrollIntoView */}
        <div ref={bottomRef} className="h-4 w-full" />
      </div>
    </div>
  );
}
