import { useEffect, useState } from "react";
import { completeLoginIfRedirected, getUser, login, logout } from "./auth";
import {
  listSections,
  createSection,
  updateSection,
  publishSection,
  deleteSection,
} from "./api";

const KINDS = ["profile", "experience", "projects", "skills", "custom"];

export default function Admin() {
  const [user, setUser] = useState(null);
  const [authChecked, setAuthChecked] = useState(false);
  const [sections, setSections] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      await completeLoginIfRedirected();
      setUser(await getUser());
      setAuthChecked(true);
    })();
  }, []);

  useEffect(() => {
    if (user && !user.expired) refresh();
  }, [user]);

  async function refresh() {
    try {
      setSections(await listSections());
    } catch (e) {
      setError(String(e));
    }
  }

  if (!authChecked) return <div className="container"><p>Loading…</p></div>;

  if (!user || user.expired) {
    return (
      <div className="container">
        <h1>Admin</h1>
        <p className="hero-summary">Sign in to edit your site content.</p>
        <button className="btn btn-primary" onClick={login}>Sign in</button>
      </div>
    );
  }

  return (
    <div className="container">
      <div className="card-header" style={{ marginTop: "2rem" }}>
        <h1>Content Admin</h1>
        <button className="btn" onClick={logout}>Sign out</button>
      </div>
      <p className="hero-summary">Signed in as {user.profile?.email}</p>
      {error && <p className="form-status err">{error}</p>}

      <button
        className="btn btn-primary"
        onClick={async () => {
          await createSection({
            kind: "custom",
            title: "New Section",
            order: (sections.at(-1)?.order ?? 0) + 1,
            data: { body: ["Edit me."], tags: [], links: [] },
          });
          refresh();
        }}
      >
        + Add section
      </button>

      <div style={{ marginTop: "1.5rem" }}>
        {sections.map((s) => (
          <SectionEditor key={s.pk} section={s} onChange={refresh} setError={setError} />
        ))}
      </div>
    </div>
  );
}

function SectionEditor({ section, onChange, setError }) {
  const id = section.pk.split("#")[1];
  const hasDraft = section.draft !== undefined;
  const current = hasDraft ? section.draft : section.published;

  const [title, setTitle] = useState(section.title || "");
  const [order, setOrder] = useState(section.order ?? 0);
  const [json, setJson] = useState(JSON.stringify(current ?? {}, null, 2));
  const [saving, setSaving] = useState(false);

  async function save() {
    let data;
    try {
      data = JSON.parse(json);
    } catch {
      setError("Invalid JSON in " + (title || id));
      return;
    }
    setSaving(true);
    try {
      await updateSection(id, { title, order: Number(order), data });
      await onChange();
    } catch (e) {
      setError(String(e));
    } finally {
      setSaving(false);
    }
  }

  return (
    <article className="card">
      <div className="card-header">
        <h4>
          {section.kind}
          {hasDraft && <span className="tag" style={{ marginLeft: ".5rem" }}>draft</span>}
          {section.published && !hasDraft && (
            <span className="tag" style={{ marginLeft: ".5rem" }}>live</span>
          )}
        </h4>
        <span className="card-period">order {section.order}</span>
      </div>

      <label className="contact-form" style={{ gap: ".5rem" }}>
        Title
        <input value={title} onChange={(e) => setTitle(e.target.value)} />
        Order
        <input type="number" value={order} onChange={(e) => setOrder(e.target.value)} />
        Data (JSON)
        <textarea rows="8" value={json} onChange={(e) => setJson(e.target.value)} />
      </label>

      <div className="hero-links" style={{ marginTop: ".75rem" }}>
        <button className="btn" disabled={saving} onClick={save}>
          {saving ? "Saving…" : "Save draft"}
        </button>
        <button
          className="btn btn-primary"
          onClick={async () => { await publishSection(id); onChange(); }}
        >
          Publish
        </button>
        <button
          className="btn"
          onClick={async () => {
            if (confirm("Delete this section?")) { await deleteSection(id); onChange(); }
          }}
        >
          Delete
        </button>
      </div>
    </article>
  );
}
