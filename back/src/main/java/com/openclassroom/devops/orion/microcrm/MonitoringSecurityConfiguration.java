package com.openclassroom.devops.orion.microcrm;

import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class MonitoringSecurityConfiguration {

    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            MonitoringAuthenticationEntryPoint authenticationEntryPoint) throws Exception {
        return http
                .securityMatcher("/internal/auth-check")
                .authorizeHttpRequests(authorize -> authorize
                        .anyRequest().authenticated())
                .httpBasic(httpBasic -> httpBasic.authenticationEntryPoint(authenticationEntryPoint))
                .build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    UserDetailsService monitoringUserDetailsService(
            PasswordEncoder passwordEncoder,
            @Value("${microcrm.monitoring.username}") String username,
            @Value("${microcrm.monitoring.password}") String password) {
        String effectivePassword = password.isBlank() ? UUID.randomUUID().toString() : password;
        return new InMemoryUserDetailsManager(User.withUsername(username)
                .password(passwordEncoder.encode(effectivePassword))
                .roles("MONITORING")
                .build());
    }
}
