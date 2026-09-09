package com.openclassroom.devops.orion.microcrm;

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class MonitoringAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private static final Logger LOGGER = LoggerFactory.getLogger(MonitoringAuthenticationEntryPoint.class);

    private final CloudWatchStatsdClient metrics;

    public MonitoringAuthenticationEntryPoint(CloudWatchStatsdClient metrics) {
        this.metrics = metrics;
    }

    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authenticationException) throws IOException {
        metrics.increment("AuthenticationFailureCount");
        LOGGER.warn("Échec d'authentification sur le contrôle interne de monitoring");
        response.sendError(HttpServletResponse.SC_UNAUTHORIZED);
    }
}
