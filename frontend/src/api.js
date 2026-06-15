// All API calls. Public reads need no auth; admin calls attach the Cognito
// ID token. URLs are relative — CloudFront routes /api/content and /api/admin/*
// to API Gateway (and /api/contact to the ALB). In dev, Vite proxies them.
import { getToken } from "./auth";

export async function getContent() {
  const res = await fetch("/api/content");
  if (!res.ok) throw new Error(`content ${res.status}`);
  return (await res.json()).sections;
}

async function adminFetch(path, options = {}) {
  const token = await getToken();
  if (!token) throw new Error("not authenticated");
  const res = await fetch(`/api/admin${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(options.headers || {}),
    },
  });
  if (!res.ok) throw new Error(`admin ${res.status}`);
  return res.status === 204 ? null : res.json();
}

export const listSections = () => adminFetch("/sections").then((r) => r.sections);
export const createSection = (body) =>
  adminFetch("/sections", { method: "POST", body: JSON.stringify(body) });
export const updateSection = (id, body) =>
  adminFetch(`/sections/${id}`, { method: "PUT", body: JSON.stringify(body) });
export const publishSection = (id) =>
  adminFetch(`/sections/${id}/publish`, { method: "POST" });
export const deleteSection = (id) => adminFetch(`/sections/${id}`, { method: "DELETE" });
