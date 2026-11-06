package ru.mumusic.api.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Сырые значения из application.yml / переменных окружения. Проверяет и разбирает их {@link AppConfig}. */
@ConfigurationProperties(prefix = "app")
public record AppProperties(
        String env,
        Database database,
        Jwt jwt,
        String storageRoot,
        String corsOrigins
) {
    public record Database(String url, String ssl, Integer poolMax) {}

    public record Jwt(String accessSecret, String refreshSecret, String accessTtl, String refreshTtl, String mediaTtl) {}
}
