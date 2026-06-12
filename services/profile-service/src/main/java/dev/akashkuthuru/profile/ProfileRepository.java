package dev.akashkuthuru.profile;

import dev.akashkuthuru.profile.model.Profile;
import dev.akashkuthuru.profile.model.Profile.Job;
import dev.akashkuthuru.profile.model.Profile.SkillGroup;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * In-memory profile data for now. The interface is shaped so this can be
 * swapped for a DynamoDB-backed implementation without touching the controller.
 */
@Repository
public class ProfileRepository {

    private static final Profile PROFILE = new Profile(
            "Sai Akash Kuthuru",
            "Software Developer",
            "Plano, TX",
            "saiakash5@gmail.com",
            "https://www.linkedin.com/in/akashkuthuru/",
            "Backend developer with 6+ years of experience building resilient financial and insurance "
                    + "applications with Java, Spring Boot, and AWS.",
            List.of(
                    new Job(
                            "JPMorgan Chase", "Plano, TX", "Software Developer", "2021 – Present",
                            List.of("Java", "Spring Boot", "AWS", "PCF", "REST", "Resilience4J", "Spinnaker"),
                            List.of(
                                    "Design and develop resilient microservices used by Chase.com and Chase Investments.",
                                    "Migrated an on-prem GAIA-based application to AWS end to end.",
                                    "Built a composite Spinnaker pipeline for blue-green deployments with immediate rollback.",
                                    "Designed a Market Data API supporting real-time prices for equities and ETFs.",
                                    "Reduced downtime from failed database calls using Resilience4J.")),
                    new Job(
                            "Vitech Systems Group", "Iselin, NJ", "Software Developer", "2018 – 2021",
                            List.of("Java", "Spring", "Hibernate", "PostgreSQL", "Oracle"),
                            List.of(
                                    "Customized the V3 Core product for insurance and healthcare clients.",
                                    "Developed complex claim-validation rules.",
                                    "Optimized processes by rebuilding existing solutions.")),
                    new Job(
                            "Vanderbilt University Medical Center", "Nashville, TN", "Application Developer", "2018",
                            List.of("Java", "Spring", "Hibernate", "AWS SNS"),
                            List.of(
                                    "Built an application for investigators to request human tissue for research.",
                                    "Added SMS notifications to the CHTN application using AWS SNS."))),
            List.of(
                    new SkillGroup("Languages", List.of("Java", "SQL", "Python", "JavaScript")),
                    new SkillGroup("Frameworks", List.of("Spring Boot", "Spring", "Hibernate", "FastAPI", "React")),
                    new SkillGroup("Cloud & DevOps",
                            List.of("AWS", "Terraform", "Docker", "ECS", "DynamoDB", "Spinnaker", "PCF"))),
            List.of("AWS Certified Developer – Associate (2022)"));

    public Profile getProfile() {
        return PROFILE;
    }
}
