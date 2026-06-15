"""Seed the DynamoDB content table from the current resume data.

One-time migration of the static profile.js content into DynamoDB. Each
section is written as already-published so the public site shows it immediately.

    python scripts/seed_content.py            # seed (skips existing items)
    python scripts/seed_content.py --force    # overwrite existing items
"""

import sys
import boto3

TABLE = "akash-portfolio-content"
FORCE = "--force" in sys.argv

SECTIONS = [
    {
        "pk": "SECTION#profile",
        "kind": "profile",
        "title": "Profile",
        "order": 0,
        "published": {
            "name": "Sai Akash Kuthuru",
            "title": "Software Developer",
            "location": "Plano, TX",
            "email": "saiakash5@gmail.com",
            "linkedin": "https://www.linkedin.com/in/akashkuthuru/",
            "github": "https://github.com/saiakash5",
            "summary": (
                "Backend developer with 7+ years of experience designing and building "
                "resilient financial and insurance applications on Java, Spring Boot, and "
                "AWS — currently expanding into Python and modern frontend development."
            ),
            "facts": ["7+ years experience", "AWS Certified Developer", "Plano, TX"],
        },
    },
    {
        "pk": "SECTION#experience",
        "kind": "experience",
        "title": "Experience",
        "order": 1,
        "published": {
            "items": [
                {
                    "company": "JPMorgan Chase", "location": "Plano, TX",
                    "role": "Software Developer", "period": "2021 – Present",
                    "stack": ["Java", "Spring Boot", "AWS", "PCF", "REST", "Resilience4J", "Spinnaker"],
                    "highlights": [
                        "Design and develop resilient microservices consumed by internal clients including Chase.com and Chase Investments.",
                        "Led the end-to-end migration of an on-prem GAIA-based application to AWS.",
                        "Built a composite Spinnaker pipeline that gives the team blue-green deployments with instant rollback.",
                        "Own the services behind the investment-platform login experience — delivered performance gains and reduced downtime at both the application and infrastructure level.",
                        "Designed and developed a Market Data API serving real-time equity and ETF prices.",
                        "Cut downtime caused by database failures by introducing Resilience4J circuit breakers.",
                        "Migrated legacy downstream integrations to RESTful services end to end.",
                    ],
                },
                {
                    "company": "Vitech Systems Group", "location": "Iselin, NJ",
                    "role": "Software Developer", "period": "2018 – 2021",
                    "stack": ["Java", "Spring", "Hibernate", "PostgreSQL", "Oracle"],
                    "highlights": [
                        "Customized the V3 Core product to meet the requirements of multiple insurance and healthcare clients.",
                        "Designed and implemented complex claim-validation rules for reported claims.",
                        "Simplified and optimized existing processes by analyzing business requirements and rebuilding legacy solutions.",
                        "Partnered with the company's demo team to showcase the V3 platform to prospective clients.",
                    ],
                },
                {
                    "company": "Vanderbilt University Medical Center", "location": "Nashville, TN",
                    "role": "Application Developer", "period": "2018",
                    "stack": ["Java", "Spring", "Hibernate", "AWS SNS"],
                    "highlights": [
                        "Built an online portal for research investigators to register and request human tissue samples for approved research projects.",
                        "Added SMS notifications to the CHTN application for medical-center customers using AWS SNS.",
                    ],
                },
            ]
        },
    },
    {
        "pk": "SECTION#projects",
        "kind": "projects",
        "title": "Projects",
        "order": 2,
        "published": {
            "items": [
                {
                    "name": "This Portfolio Platform",
                    "description": (
                        "The site you're looking at — a fully serverless AWS platform: React on "
                        "S3 + CloudFront, content served live from DynamoDB via Lambda + API Gateway, "
                        "a Cognito-secured admin portal, WAF at the edge, all defined in Terraform."
                    ),
                    "tags": ["AWS", "Terraform", "Lambda", "API Gateway", "DynamoDB", "Cognito"],
                    "link": "https://github.com/saiakash5/akash-portfolio",
                },
                {
                    "name": "Similarity Measures via Sketching Algorithms",
                    "description": "Implemented Adamic-Adar, Common Neighbors, Preferential Attachment, and Jaccard Coefficient similarity measures with sketching algorithms — graph sketches cut computation time by 33%.",
                    "tags": ["Algorithms", "Graphs", "Java"],
                },
                {
                    "name": "Fitbit Data Visualization",
                    "description": "Built a Fitbit-API-powered app that maps user locations with the Google Maps API and visualizes activity data with Google Charts.",
                    "tags": ["JavaScript", "Google Maps API", "Data Viz"],
                },
            ]
        },
    },
    {
        "pk": "SECTION#skills",
        "kind": "skills",
        "title": "Skills",
        "order": 3,
        "published": {
            "groups": [
                {"category": "Languages", "items": ["Java", "SQL", "Python (learning)", "JavaScript (learning)"]},
                {"category": "Frameworks", "items": ["Spring Boot", "Spring", "Hibernate", "FastAPI", "React"]},
                {"category": "Cloud & DevOps", "items": ["AWS (ECS, Lambda, DynamoDB, Cognito, Route 53)", "Terraform", "Docker", "Spinnaker", "PCF"]},
                {"category": "Practices", "items": ["Microservices", "REST API design", "Blue-green deployments", "Resilience patterns", "IaC"]},
            ],
            "education": [
                {"degree": "M.S. in Computer Science", "school": "University of Louisiana at Lafayette", "year": "2017"},
                {"degree": "B.Tech in Computer Science", "school": "Jawaharlal Nehru Technological University", "year": "2015"},
            ],
            "certifications": [
                {"name": "AWS Certified Developer – Associate", "year": "2022"},
            ],
        },
    },
]


def main():
    table = boto3.resource("dynamodb", region_name="us-east-1").Table(TABLE)
    for s in SECTIONS:
        if not FORCE:
            existing = table.get_item(Key={"pk": s["pk"]}).get("Item")
            if existing:
                print(f"skip  {s['pk']} (exists)")
                continue
        table.put_item(Item=s)
        print(f"wrote {s['pk']}")
    print("done.")


if __name__ == "__main__":
    main()
