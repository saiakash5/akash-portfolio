import { useEffect, useState } from "react";
import Nav from "./components/Nav";
import Hero from "./components/Hero";
import Experience from "./components/Experience";
import Projects from "./components/Projects";
import Skills from "./components/Skills";
import CustomSection from "./components/CustomSection";
import Contact from "./components/Contact";
import { useReveal } from "./useReveal";
import { getContent } from "./api";

// kind -> component for dynamic rendering of fetched sections.
const RENDERERS = {
  profile: Hero,
  experience: Experience,
  projects: Projects,
  skills: Skills,
  custom: CustomSection,
};

export default function PublicSite() {
  const [sections, setSections] = useState(null); // null = still loading

  useEffect(() => {
    getContent()
      .then((s) => setSections(s))
      .catch(() => setSections([])); // empty → components fall back to static seed
  }, []);

  // Re-run the scroll-reveal observer whenever sections change.
  useReveal([sections]);

  // Before the API responds (or if it's empty), render the components with no
  // data — each falls back to the static seed in data/profile.js, so the site
  // is never blank.
  const ordered = (sections || []).slice().sort((a, b) => a.order - b.order);

  return (
    <>
      <Nav />
      <main className="container">
        {ordered.length === 0 ? (
          <>
            <Hero />
            <Experience />
            <Projects />
            <Skills />
          </>
        ) : (
          ordered.map((s) => {
            const Component = RENDERERS[s.kind] || CustomSection;
            return <Component key={s.id} data={s.data} title={s.title} />;
          })
        )}
        <Contact />
        <footer>
          <p>
            Built with React · AWS Lambda · API Gateway · DynamoDB · Cognito · Terraform — fully
            serverless.
          </p>
        </footer>
      </main>
    </>
  );
}
