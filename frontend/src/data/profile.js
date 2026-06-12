// ============================================================
//  YOUR CONTENT LIVES HERE — this is the only file you need to
//  edit to change what the site says. See frontend/EDITING.md
//  for copy-paste recipes (new job, new project, new section).
// ============================================================

export const profile = {
  name: "Sai Akash Kuthuru",
  title: "Software Developer",
  location: "Plano, TX",
  email: "saiakash5@gmail.com",
  linkedin: "https://www.linkedin.com/in/akashkuthuru/",
  github: "https://github.com/akashkuthuru",
  summary:
    "Backend developer with 6+ years of experience building resilient financial and insurance applications with Java, Spring Boot, and AWS. Currently expanding into Python and modern frontend development.",
  // Short facts shown as chips under the intro. Add/remove freely.
  facts: ["6+ years experience", "AWS Certified Developer", "Plano, TX"],
};

export const experience = [
  {
    company: "JPMorgan Chase",
    location: "Plano, TX",
    role: "Software Developer",
    period: "2021 – Present",
    stack: ["Java", "Spring Boot", "AWS", "PCF", "REST", "Resilience4J", "Spinnaker"],
    highlights: [
      "Design and develop resilient microservices used by internal clients like Chase.com and Chase Investments.",
      "Migrated an on-prem GAIA-based application to AWS with full end-to-end implementation.",
      "Built a composite Spinnaker pipeline providing blue-green deployments with immediate rollback.",
      "Own services that power the login page for investment platforms — improved performance and reduced downtime at both the functional and infrastructure level.",
      "Designed and developed a Market Data API supporting real-time prices for equities and ETFs.",
      "Reduced downtime from failed database calls using Resilience4J circuit breakers.",
    ],
  },
  {
    company: "Vitech Systems Group",
    location: "Iselin, NJ",
    role: "Software Developer",
    period: "2018 – 2021",
    stack: ["Java", "Spring", "Hibernate", "PostgreSQL", "Oracle"],
    highlights: [
      "Customized the V3 Core product for multiple insurance and healthcare clients.",
      "Developed complex claim-validation rules for reported claims.",
      "Optimized existing solutions by analyzing business requirements and rebuilding processes.",
    ],
  },
  {
    company: "Vanderbilt University Medical Center",
    location: "Nashville, TN",
    role: "Application Developer",
    period: "2018",
    stack: ["Java", "Spring", "Hibernate", "AWS SNS"],
    highlights: [
      "Built an application for investigators to register and request human tissue for research projects.",
      "Added SMS notifications to the CHTN application using AWS SNS.",
    ],
  },
];

export const skills = [
  {
    category: "Languages",
    items: ["Java", "SQL", "Python (learning)", "JavaScript (learning)"],
  },
  {
    category: "Frameworks",
    items: ["Spring Boot", "Spring", "Hibernate", "FastAPI", "React"],
  },
  {
    category: "Cloud & DevOps",
    items: ["AWS (ECS, ALB, Route 53, DynamoDB, SNS)", "Terraform", "Docker", "Spinnaker", "PCF"],
  },
  {
    category: "Practices",
    items: ["Microservices", "REST API design", "Blue-green deployments", "Resilience patterns", "Multi-region DR"],
  },
];

export const projects = [
  {
    name: "This Portfolio Platform",
    description:
      "The site you're looking at — a polyglot microservices platform: React frontend on S3 + CloudFront, Spring Boot and FastAPI services on ECS Fargate behind an ALB, DynamoDB Global Tables, deployed to two AWS regions in an active-dormant DR setup with Route 53 failover. Fully defined in Terraform.",
    tags: ["AWS", "Terraform", "Spring Boot", "FastAPI", "React", "Multi-region DR"],
    link: "https://github.com/akashkuthuru",
  },
  {
    name: "Similarity Measures via Sketching Algorithms",
    description:
      "Implemented Adamic-Adar, Common Neighbors, Preferential Attachment, and Jaccard Coefficient similarity measures using graph sketches, reducing result time by 33%.",
    tags: ["Algorithms", "Graphs", "Java"],
  },
  {
    name: "Fitbit Data Visualization",
    description:
      "Visualized Fitbit activity data and user locations using the Fitbit API, Google Maps API, and Google Charts.",
    tags: ["JavaScript", "Google Maps API", "Data Viz"],
  },
];

export const education = [
  {
    degree: "M.S. in Computer Science",
    school: "University of Louisiana at Lafayette",
    year: "2017",
  },
  {
    degree: "B.Tech in Computer Science",
    school: "Jawaharlal Nehru Technological University",
    year: "2015",
  },
];

export const certifications = [
  { name: "AWS Certified Developer – Associate", year: "2022" },
];

// ============================================================
//  CUSTOM BLOCKS — add any extra section without writing React.
//  Each block becomes its own section on the page, in order.
//  Every field except `title` is optional. Uncomment the example
//  below to see how it works.
// ============================================================

export const extras = [
  // {
  //   title: "Beyond the Code",
  //   body: [
  //     "First paragraph about hobbies, interests, or anything personal.",
  //     "Second paragraph if you want one.",
  //   ],
  //   tags: ["Cricket", "Cooking", "Travel"],
  //   links: [{ label: "My blog", url: "https://example.com" }],
  // },
];
