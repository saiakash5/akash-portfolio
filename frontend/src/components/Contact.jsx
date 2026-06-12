import { useState } from "react";
import { profile } from "../data/profile";

// Posts to the FastAPI contact-service. In local dev, Vite proxies /api
// to localhost:8001 (see vite.config.js). In AWS, CloudFront/ALB routes it.
export default function Contact() {
  const [form, setForm] = useState({ name: "", email: "", message: "" });
  const [status, setStatus] = useState("idle"); // idle | sending | sent | error

  function update(field) {
    return (e) => setForm({ ...form, [field]: e.target.value });
  }

  async function submit(e) {
    e.preventDefault();
    setStatus("sending");
    try {
      const res = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setStatus("sent");
      setForm({ name: "", email: "", message: "" });
    } catch {
      setStatus("error");
    }
  }

  return (
    <section id="contact">
      <h3>Get in Touch</h3>
      <form className="card contact-form" onSubmit={submit}>
        <label>
          Name
          <input value={form.name} onChange={update("name")} required />
        </label>
        <label>
          Email
          <input type="email" value={form.email} onChange={update("email")} required />
        </label>
        <label>
          Message
          <textarea rows="4" value={form.message} onChange={update("message")} required />
        </label>
        <button type="submit" disabled={status === "sending"}>
          {status === "sending" ? "Sending…" : "Send Message"}
        </button>
        {status === "sent" && <p className="form-status ok">Thanks! I'll get back to you soon.</p>}
        {status === "error" && (
          <p className="form-status err">
            Couldn't reach the API — email me directly at{" "}
            <a href={`mailto:${profile.email}`}>{profile.email}</a>.
          </p>
        )}
      </form>
    </section>
  );
}
