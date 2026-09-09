package com.openclassroom.devops.orion.microcrm;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MonitoringController {

    private final String environment;
    private final String track;
    private final String version;

    public MonitoringController(
            @Value("${microcrm.deployment.environment}") String environment,
            @Value("${microcrm.deployment.track}") String track,
            @Value("${microcrm.release.version}") String version) {
        this.environment = environment;
        this.track = track;
        this.version = version;
    }

    @GetMapping("/internal/auth-check")
    Map<String, String> authenticationCheck() {
        return Map.of("environment", environment, "track", track, "version", version);
    }
}
