import { projects as staticProjects } from "../data/profile";

export default function Projects({ data, title }) {
  const items = data?.items || staticProjects;
  return (
    <section id="projects" className="reveal">
      <h3>{title || "Projects"}</h3>
      {items.map((p) => (
        <article className="card" key={p.name}>
          <div className="card-header">
            <h4>
              {p.link ? (
                <a href={p.link} target="_blank" rel="noreferrer">{p.name}</a>
              ) : (
                p.name
              )}
            </h4>
          </div>
          <p>{p.description}</p>
          {p.tags?.length > 0 && (
            <div className="tags">
              {p.tags.map((t) => (
                <span className="tag" key={t}>{t}</span>
              ))}
            </div>
          )}
        </article>
      ))}
    </section>
  );
}
