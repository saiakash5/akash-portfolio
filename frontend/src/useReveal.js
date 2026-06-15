import { useEffect } from "react";

// Adds a gentle fade-up to every element with class "reveal" as it
// scrolls into view. Respects prefers-reduced-motion (see index.css).
// Pass deps (e.g. [sections]) so it re-scans after async content renders.
export function useReveal(deps = []) {
  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("revealed");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.08 }
    );

    document.querySelectorAll(".reveal:not(.revealed)").forEach((el) => observer.observe(el));
    return () => observer.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);
}
