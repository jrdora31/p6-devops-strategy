package com.openclassroom.devops.orion.microcrm;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "microcrm.monitoring.username=test-monitoring",
        "microcrm.monitoring.password=test-password",
        "microcrm.release.version=v1.2.3"
})
@AutoConfigureMockMvc
class MonitoringSecurityIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void normalApiRemainsPublic() throws Exception {
        mockMvc.perform(get("/persons"))
                .andExpect(status().isOk());
    }

    @Test
    void invalidCredentialsProduceARealAuthenticationFailure() throws Exception {
        mockMvc.perform(get("/internal/auth-check")
                .with(httpBasic("test-monitoring", "invalid-password")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void validCredentialsExposeOnlyDeploymentIdentity() throws Exception {
        mockMvc.perform(get("/internal/auth-check")
                .with(httpBasic("test-monitoring", "test-password")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.track").value("stable"))
                .andExpect(jsonPath("$.version").value("v1.2.3"));
    }
}
