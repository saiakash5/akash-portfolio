import Hero from "./components/Hero";
import Experience from "./components/Experience";
import Skills from "./components/Skills";
import Projects from "./components/Projects";
import Contact from "./components/Contact";

export default function App() {
  return (
    <main className="container">
      <Hero />
      <Experience />
      <Projects />
      <Skills />
      <Contact />
      <footer>
        <p>
          Built with React · Spring Boot · FastAPI · Terraform — running on AWS ECS across two
          regions.
        </p>
      </footer>
    </main>
  );
}
