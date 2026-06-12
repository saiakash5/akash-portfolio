package dev.akashkuthuru.profile.model;

import java.util.List;

public record Profile(
        String name,
        String title,
        String location,
        String email,
        String linkedin,
        String summary,
        List<Job> experience,
        List<SkillGroup> skills,
        List<String> certifications) {

    public record Job(
            String company,
            String location,
            String role,
            String period,
            List<String> stack,
            List<String> highlights) {
    }

    public record SkillGroup(String category, List<String> items) {
    }
}
