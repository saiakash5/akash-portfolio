import Nav from "./components/Nav";
import Hero from "./components/Hero";
import Experience from "./components/Experience";
import Skills from "./components/Skills";
import Projects from "./components/Projects";
import Extras from "./components/Extras";
import Contact from "./components/Contact";
import { useReveal } from "./useReveal";

export default function App() {
  useReveal();

  return (
    <>
      <Nav />
      <main className="container">
        <Hero />
        <Experience />
        <Projects />
        <Skills />
        <Extras />
        <Contact />
        <footer>
          <p>
            Built with React · Spring Boot · FastAPI · Terraform — running on AWS ECS across two
            regions.
          </p>
        </footer>
      </main>
    </>
  );
}
