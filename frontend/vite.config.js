import path from "path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite"; // NEW: Import the v4 plugin

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(), // NEW: Add it to the plugins array
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
