import { extras } from "../data/profile";

// Renders the custom blocks from profile.js. Each block is a section
// of its own — no React knowledge needed to add one.
export default function Extras() {
  if (!extras.length) return null;

  return (
    <>
      {extras.map((block) => (
        <section className="reveal" key={block.title} id={block.title.toLowerCase().replace(/\s+/g, "-")}>
          <h3>{block.title}</h3>
          <div className="card">
            {(block.body || []).map((p) => (
              <p key={p}>{p}</p>
            ))}
            {block.links?.length > 0 && (
              <p className="extra-links">
                {block.links.map((l) => (
                  <a key={l.url} href={l.url} target="_blank" rel="noreferrer">
                    {l.label} ↗
                  </a>
                ))}
              </p>
            )}
            {block.tags?.length > 0 && (
              <div className="tags">
                {block.tags.map((t) => (
                  <span className="tag" key={t}>
                    {t}
                  </span>
                ))}
              </div>
            )}
          </div>
        </section>
      ))}
    </>
  );
}
