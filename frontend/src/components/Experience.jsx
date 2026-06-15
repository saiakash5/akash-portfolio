import { experience as staticExperience } from "../data/profile";

export default function Experience({ data, title }) {
  const jobs = data?.items || staticExperience;
  return (
    <section id="experience" className="reveal">
      <h3>{title || "Experience"}</h3>
      {jobs.map((job) => (
        <article className="card" key={job.company + job.role}>
          <div className="card-header">
            <div>
              <h4>{job.role}</h4>
              <p className="card-subtitle">
                {job.company}{job.location ? ` · ${job.location}` : ""}
              </p>
            </div>
            {job.period && <span className="card-period">{job.period}</span>}
          </div>
          <ul>
            {(job.highlights || []).map((h) => (
              <li key={h}>{h}</li>
            ))}
          </ul>
          {job.stack?.length > 0 && (
            <div className="tags">
              {job.stack.map((s) => (
                <span className="tag" key={s}>{s}</span>
              ))}
            </div>
          )}
        </article>
      ))}
    </section>
  );
}
