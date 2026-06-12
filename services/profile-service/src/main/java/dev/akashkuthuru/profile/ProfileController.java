package dev.akashkuthuru.profile;

import dev.akashkuthuru.profile.model.Profile;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/profile")
public class ProfileController {

    private final ProfileRepository repository;

    public ProfileController(ProfileRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public Profile profile() {
        return repository.getProfile();
    }

    @GetMapping("/experience")
    public List<Profile.Job> experience() {
        return repository.getProfile().experience();
    }

    @GetMapping("/skills")
    public List<Profile.SkillGroup> skills() {
        return repository.getProfile().skills();
    }
}
