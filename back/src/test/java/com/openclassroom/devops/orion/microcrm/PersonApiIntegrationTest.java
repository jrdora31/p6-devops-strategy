package com.openclassroom.devops.orion.microcrm;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class PersonApiIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void shouldCreateReadUpdateAndDeletePerson() throws Exception {
        MvcResult creation = mockMvc.perform(post("/persons")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "firstName": "Jane",
                          "lastName": "Doe",
                          "email": "jane.doe@example.net"
                        }
                        """))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andReturn();

        String location = creation.getResponse().getHeader("Location");
        long personId = Long.parseLong(location.substring(location.lastIndexOf('/') + 1));

        mockMvc.perform(get("/persons/{id}", personId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("jane.doe@example.net"));

        mockMvc.perform(patch("/persons/{id}", personId)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        { "phone": "+33 1 23 45 67 89" }
                        """))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/persons/{id}", personId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phone").value("+33 1 23 45 67 89"));

        mockMvc.perform(delete("/persons/{id}", personId))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/persons/{id}", personId))
                .andExpect(status().isNotFound());
    }
}
