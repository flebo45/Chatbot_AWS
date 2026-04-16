"use client"

import { cn } from "@/lib/utils"
import { Sparkles } from "lucide-react"

interface ChatHeaderProps {
  modelName?: string
  isOnline?: boolean
}

export function ChatHeader({ modelName = "Nova AI", isOnline = true }: ChatHeaderProps) {
  return (
    <header className="sticky top-0 z-10 flex items-center justify-center gap-3 border-b border-border bg-background/80 backdrop-blur-sm px-4 py-3">
      <div className="flex items-center gap-2">
        <div className="flex size-8 items-center justify-center rounded-lg bg-primary">
          <Sparkles className="size-4 text-primary-foreground" />
        </div>
        <div className="flex flex-col">
          <span className="text-sm font-semibold text-foreground">{modelName}</span>
          <div className="flex items-center gap-1.5">
            <span
              className={cn(
                "size-1.5 rounded-full",
                isOnline ? "bg-emerald-500" : "bg-muted-foreground"
              )}
            />
            <span className="text-xs text-muted-foreground">
              {isOnline ? "Online" : "Offline"}
            </span>
          </div>
        </div>
      </div>
    </header>
  )
}
