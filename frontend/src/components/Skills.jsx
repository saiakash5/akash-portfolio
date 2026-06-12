import { skills, certifications, education } from "../data/profile";

export default function Skills() {
  return (
    <section id="skills" className="reveal">
      <h3>Skills</h3>
      <div className="skills-grid">
        {skills.map((group) => (
          <div className="card" key={group.category}>
            <h4>{group.category}</h4>
            <div className="tags">
              {group.items.map((item) => (
                <span className="tag" key={item}>
                  {item}
                </span>
              ))}
            </div>
          </div>
        ))}
      </div>

      <h3>Education & Certifications</h3>
      <div className="skills-grid">
        {education.map((e) => (
          <div className="card" key={e.degree}>
            <h4>{e.degree}</h4>
            <p className="card-subtitle">
              {e.school} · {e.year}
            </p>
          </div>
        ))}
        {certifications.map((c) => (
          <div className="card" key={c.name}>
            <h4>{c.name}</h4>
            <p className="card-subtitle">{c.year}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
