import { profile } from "../data/profile";

export default function Hero() {
  return (
    <header className="hero" id="top">
      <p className="hero-kicker">{profile.title}</p>
      <h1>{profile.name}</h1>
      <p className="hero-summary">{profile.summary}</p>

      <div className="hero-facts">
        {profile.facts.map((f) => (
          <span className="fact" key={f}>
            {f}
          </span>
        ))}
      </div>

      <div className="hero-links">
        <a className="btn btn-primary" href="#contact">
          Get in touch
        </a>
        <a className="btn" href={`mailto:${profile.email}`}>
          Email
        </a>
        <a className="btn" href={profile.linkedin} target="_blank" rel="noreferrer">
          LinkedIn
        </a>
        {profile.github && (
          <a className="btn" href={profile.github} target="_blank" rel="noreferrer">
            GitHub
          </a>
        )}
      </div>
    </header>
  );
}
