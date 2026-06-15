// Renders a custom section (e.g. Hobbies) created in the admin portal.
// data shape: { body: string[], tags: string[], links: [{label,url}] }
export default function CustomSection({ data, title }) {
  const d = data || {};
  const id = (title || "section").toLowerCase().replace(/\s+/g, "-");
  return (
    <section className="reveal" id={id}>
      <h3>{title}</h3>
      <div className="card">
        {(d.body || []).map((p) => (
          <p key={p}>{p}</p>
        ))}
        {d.links?.length > 0 && (
          <p className="extra-links">
            {d.links.map((l) => (
              <a key={l.url} href={l.url} target="_blank" rel="noreferrer">
                {l.label} ↗
              </a>
            ))}
          </p>
        )}
        {d.tags?.length > 0 && (
          <div className="tags">
            {d.tags.map((t) => (
              <span className="tag" key={t}>{t}</span>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
