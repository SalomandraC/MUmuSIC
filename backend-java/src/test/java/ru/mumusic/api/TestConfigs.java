package ru.mumusic.api;

import ru.mumusic.api.config.AppConfig;
import ru.mumusic.api.config.AppProperties;

public final class TestConfigs {

    public static final String ACCESS = "test-access-secret-0123456789abcdef0123456789";
    public static final String REFRESH = "test-refresh-secret-0123456789abcdef012345678";

    private TestConfigs() {}

    public static AppConfig config(String accessTtl) {
        return new AppConfig(new AppProperties(
                "test",
                new AppProperties.Database("postgres://u:p@localhost:5432/db", null, null),
                new AppProperties.Jwt(ACCESS, REFRESH, accessTtl, "7d", "7d"),
                "/tmp/mumusic-test-storage",
                ""));
    }

    public static AppConfig config() {
        return config("60m");
    }
}
