import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      // Mirrors the ALB path routing in AWS:
      //   /api/profile/* -> Spring Boot profile-service (port 8080)
      //   /api/contact   -> FastAPI contact-service (port 8001)
      "/api/profile": "http://localhost:8080",
      "/api/contact": "http://localhost:8001",
    },
  },
});
