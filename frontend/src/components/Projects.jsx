import { projects } from "../data/profile";

export default function Projects() {
  return (
    <section id="projects">
      <h3>Projects</h3>
      {projects.map((p) => (
        <article className="card" key={p.name}>
          <div className="card-header">
            <h4>
              {p.link ? (
                <a href={p.link} target="_blank" rel="noreferrer">
                  {p.name}
                </a>
              ) : (
                p.name
              )}
            </h4>
          </div>
          <p>{p.description}</p>
          <div className="tags">
            {p.tags.map((t) => (
              <span className="tag" key={t}>
                {t}
              </span>
            ))}
          </div>
        </article>
      ))}
    </section>
  );
}
