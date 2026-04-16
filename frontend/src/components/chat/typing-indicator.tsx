"use client"

import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Sparkles } from "lucide-react"

export function TypingIndicator() {
  return (
    <div className="flex gap-3 px-4 py-4 md:px-6">
      <Avatar className="size-8 shrink-0 bg-secondary">
        <AvatarFallback className="bg-secondary text-secondary-foreground">
          <Sparkles className="size-4" />
        </AvatarFallback>
      </Avatar>
      <div className="flex items-center gap-1 rounded-2xl rounded-bl-md bg-secondary px-4 py-3">
        <span className="size-2 animate-bounce rounded-full bg-muted-foreground [animation-delay:-0.3s]" />
        <span className="size-2 animate-bounce rounded-full bg-muted-foreground [animation-delay:-0.15s]" />
        <span className="size-2 animate-bounce rounded-full bg-muted-foreground" />
      </div>
    </div>
  )
}
