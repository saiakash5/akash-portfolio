import { profile as staticProfile } from "../data/profile";

// `data` comes from the content API; falls back to static seed data.
export default function Hero({ data }) {
  const p = data || staticProfile;
  return (
    <header className="hero" id="top">
      <p className="hero-kicker">{p.title}</p>
      <h1>{p.name}</h1>
      <p className="hero-summary">{p.summary}</p>

      {p.facts?.length > 0 && (
        <div className="hero-facts">
          {p.facts.map((f) => (
            <span className="fact" key={f}>{f}</span>
          ))}
        </div>
      )}

      <div className="hero-links">
        <a className="btn btn-primary" href="#contact">Get in touch</a>
        {p.email && <a className="btn" href={`mailto:${p.email}`}>Email</a>}
        {p.linkedin && <a className="btn" href={p.linkedin} target="_blank" rel="noreferrer">LinkedIn</a>}
        {p.github && <a className="btn" href={p.github} target="_blank" rel="noreferrer">GitHub</a>}
        <a className="btn" href="/resume.pdf" target="_blank" rel="noreferrer">Résumé</a>
      </div>
    </header>
  );
}
