import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const API_GW = "https://zlmz3brvnf.execute-api.us-east-1.amazonaws.com";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      // Content plane (serverless) — mirrors the CloudFront behaviors.
      "/api/content": { target: API_GW, changeOrigin: true },
      "/api/admin": { target: API_GW, changeOrigin: true },
      // ECS services via the ALB path routing.
      "/api/profile": "http://localhost:8080",
      "/api/contact": "http://localhost:8001",
    },
  },
});
