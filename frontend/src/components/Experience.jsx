import { experience } from "../data/profile";

export default function Experience() {
  return (
    <section id="experience" className="reveal">
      <h3>Experience</h3>
      {experience.map((job) => (
        <article className="card" key={job.company}>
          <div className="card-header">
            <div>
              <h4>{job.role}</h4>
              <p className="card-subtitle">
                {job.company} · {job.location}
              </p>
            </div>
            <span className="card-period">{job.period}</span>
          </div>
          <ul>
            {job.highlights.map((h) => (
              <li key={h}>{h}</li>
            ))}
          </ul>
          <div className="tags">
            {job.stack.map((s) => (
              <span className="tag" key={s}>
                {s}
              </span>
            ))}
          </div>
        </article>
      ))}
    </section>
  );
}
