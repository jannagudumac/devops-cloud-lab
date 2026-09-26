package com.example.devopslab;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MessageController {

    private final AtomicInteger counter = new AtomicInteger();

    @Value("${app.message:Hello from DevOps Cloud Lab}")
    private String message;

    @GetMapping("/")
    public Map<String, Object> home() {
        return Map.of(
                "service", "devops-cloud-lab",
                "message", message,
                "time", Instant.now().toString()
        );
    }

    @GetMapping("/api/message")
    public Map<String, String> message() {
        return Map.of("message", message);
    }

    @GetMapping("/api/counter")
    public Map<String, Integer> counter() {
        return Map.of("count", counter.incrementAndGet());
    }
}
