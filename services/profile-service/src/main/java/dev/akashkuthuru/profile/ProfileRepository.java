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
            "Backend developer with 7+ years of experience designing and building resilient financial "
                    + "and insurance applications on Java, Spring Boot, and AWS.",
            List.of(
                    new Job(
                            "JPMorgan Chase", "Plano, TX", "Software Developer", "2021 – Present",
                            List.of("Java", "Spring Boot", "AWS", "PCF", "REST", "Resilience4J", "Spinnaker"),
                            List.of(
                                    "Design and develop resilient microservices consumed by Chase.com and Chase Investments.",
                                    "Led the end-to-end migration of an on-prem GAIA-based application to AWS.",
                                    "Built a composite Spinnaker pipeline for blue-green deployments with instant rollback.",
                                    "Designed and developed a Market Data API serving real-time equity and ETF prices.",
                                    "Cut downtime caused by database failures using Resilience4J circuit breakers.",
                                    "Migrated legacy downstream integrations to RESTful services end to end.")),
                    new Job(
                            "Vitech Systems Group", "Iselin, NJ", "Software Developer", "2018 – 2021",
                            List.of("Java", "Spring", "Hibernate", "PostgreSQL", "Oracle"),
                            List.of(
                                    "Customized the V3 Core product to meet the requirements of insurance and healthcare clients.",
                                    "Designed and implemented complex claim-validation rules for reported claims.",
                                    "Simplified and optimized processes by rebuilding legacy solutions.",
                                    "Partnered with the demo team to showcase the V3 platform to prospective clients.")),
                    new Job(
                            "Vanderbilt University Medical Center", "Nashville, TN", "Application Developer", "2018",
                            List.of("Java", "Spring", "Hibernate", "AWS SNS"),
                            List.of(
                                    "Built an online portal for investigators to register and request human tissue samples for research.",
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
