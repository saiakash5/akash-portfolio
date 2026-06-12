import { profile } from "../data/profile";

export default function Hero() {
  return (
    <header className="hero">
      <p className="hero-kicker">{profile.location}</p>
      <h1>{profile.name}</h1>
      <h2>{profile.title}</h2>
      <p className="hero-summary">{profile.summary}</p>
      <div className="hero-links">
        <a href={`mailto:${profile.email}`}>Email</a>
        <a href={profile.linkedin} target="_blank" rel="noreferrer">
          LinkedIn
        </a>
        <a href="#contact">Contact</a>
      </div>
    </header>
  );
}
