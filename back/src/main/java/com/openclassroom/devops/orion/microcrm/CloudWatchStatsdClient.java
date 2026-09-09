package com.openclassroom.devops.orion.microcrm;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicBoolean;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import jakarta.annotation.PreDestroy;

@Component
public class CloudWatchStatsdClient {

    private static final Logger LOGGER = LoggerFactory.getLogger(CloudWatchStatsdClient.class);
    private static final String SAFE_DIMENSION = "[A-Za-z0-9._-]+";

    private final DatagramSocket socket;
    private final InetAddress address;
    private final int port;
    private final String environment;
    private final String track;
    private final String version;
    private final AtomicBoolean failureLogged = new AtomicBoolean(false);

    public CloudWatchStatsdClient(
            @Value("${microcrm.metrics.statsd.host}") String host,
            @Value("${microcrm.metrics.statsd.port}") int port,
            @Value("${microcrm.deployment.environment}") String environment,
            @Value("${microcrm.deployment.track}") String track,
            @Value("${microcrm.release.version}") String version) throws IOException {
        this.socket = new DatagramSocket();
        this.address = InetAddress.getByName(host);
        this.port = port;
        this.environment = validatedDimension("Environment", environment);
        this.track = validatedDimension("Track", track);
        this.version = validatedDimension("Version", version);
    }

    public void increment(String metricName) {
        publish(metricName, "1", "c");
    }

    public void timing(String metricName, double milliseconds) {
        publish(metricName, Double.toString(Math.max(0, milliseconds)), "ms");
    }

    private void publish(String metricName, String value, String type) {
        if (!metricName.matches(SAFE_DIMENSION)) {
            throw new IllegalArgumentException("Nom de métrique StatsD invalide");
        }

        // La série détaillée affiche la version ; la série agrégée et bornée
        // Environment/Track permet aux alarmes de suivre le Canary courant.
        send(metricName + ":" + value + "|" + type + "|#Environment:" + environment
                + ",Track:" + track + ",Version:" + version);
        send(metricName + ":" + value + "|" + type + "|#Environment:" + environment
                + ",Track:" + track);
    }

    private void send(String line) {
        byte[] payload = line.getBytes(StandardCharsets.UTF_8);
        DatagramPacket packet = new DatagramPacket(payload, payload.length, address, port);
        try {
            socket.send(packet);
        } catch (IOException exception) {
            if (failureLogged.compareAndSet(false, true)) {
                LOGGER.warn("CloudWatch StatsD indisponible; les requêtes restent servies", exception);
            }
        }
    }

    private static String validatedDimension(String name, String value) {
        if (value == null || !value.matches(SAFE_DIMENSION)) {
            throw new IllegalArgumentException(name + " contient une valeur invalide");
        }
        return value;
    }

    @PreDestroy
    void close() {
        socket.close();
    }
}
