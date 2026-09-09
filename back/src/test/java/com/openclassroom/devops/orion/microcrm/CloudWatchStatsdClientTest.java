package com.openclassroom.devops.orion.microcrm;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.nio.charset.StandardCharsets;

import org.junit.jupiter.api.Test;

class CloudWatchStatsdClientTest {

    @Test
    void publishesVersionedAndAlarmCompatibleSeries() throws Exception {
        try (DatagramSocket receiver = new DatagramSocket(0)) {
            receiver.setSoTimeout(2000);
            CloudWatchStatsdClient client = new CloudWatchStatsdClient(
                    "127.0.0.1", receiver.getLocalPort(), "production", "canary", "v1.3.0");

            client.increment("AuthenticationFailureCount");

            String first = receive(receiver);
            String second = receive(receiver);
            assertThat(first).isEqualTo("AuthenticationFailureCount:1|c|#Environment:production,Track:canary,Version:v1.3.0");
            assertThat(second).isEqualTo("AuthenticationFailureCount:1|c|#Environment:production,Track:canary");
            client.close();
        }
    }

    private static String receive(DatagramSocket receiver) throws Exception {
        byte[] buffer = new byte[512];
        DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
        receiver.receive(packet);
        return new String(packet.getData(), packet.getOffset(), packet.getLength(), StandardCharsets.UTF_8);
    }
}
