package ru.mumusic.api.config;

import org.springframework.stereotype.Component;
import ru.mumusic.api.common.TimeSpan;

import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;

/**
 * Проверенная конфигурация приложения. Повторяет правила старого appConfig.ts:
 * без DATABASE_URL и нормальных JWT-секретов сервер не стартует.
 */
@Component
public class AppConfig {

    /** Значения-заглушки из старых версий конфига: с ними токены можно подделать */
    private static final Set<String> KNOWN_WEAK_SECRETS = Set.of(
            "change-me-access-secret",
            "change-me-refresh-secret",
            "dev-session-secret"
    );

    private final String env;
    private final String databaseUrl;
    private final boolean databaseSsl;
    private final int databasePoolMax;
    private final String accessSecret;
    private final String refreshSecret;
    private final Duration accessTtl;
    private final Duration refreshTtl;
    private final Duration mediaTtl;
    private final Path storageRoot;
    private final List<String> corsOrigins;

    public AppConfig(AppProperties props) {
        List<String> errors = new ArrayList<>();

        String rawEnv = blankToNull(props.env());
        this.env = rawEnv == null ? "development" : rawEnv;
        if (!Set.of("development", "test", "production").contains(env)) {
            errors.add("APP_ENV/NODE_ENV должен быть development, test или production");
        }
        boolean production = "production".equals(env);

        AppProperties.Database db = props.database() == null
                ? new AppProperties.Database(null, null, null) : props.database();
        this.databaseUrl = blankToNull(db.url());
        if (databaseUrl == null) {
            errors.add("DATABASE_URL обязателен");
        }
        String ssl = blankToNull(db.ssl());
        if (ssl != null && !ssl.equals("require") && !ssl.equals("disable")) {
            errors.add("DATABASE_SSL должен быть require или disable");
        }
        this.databaseSsl = "require".equals(ssl != null ? ssl : (production ? "require" : "disable"));
        this.databasePoolMax = db.poolMax() == null || db.poolMax() <= 0 ? 10 : db.poolMax();

        AppProperties.Jwt jwt = props.jwt() == null
                ? new AppProperties.Jwt(null, null, null, null, null) : props.jwt();
        this.accessSecret = blankToNull(jwt.accessSecret());
        this.refreshSecret = blankToNull(jwt.refreshSecret());
        checkSecret("JWT_ACCESS_SECRET", accessSecret, errors);
        checkSecret("JWT_REFRESH_SECRET", refreshSecret, errors);
        if (accessSecret != null && accessSecret.equals(refreshSecret)) {
            errors.add("JWT_ACCESS_SECRET и JWT_REFRESH_SECRET должны различаться");
        }

        this.accessTtl = parseTtl("ACCESS_TOKEN_TTL", jwt.accessTtl(), "60m", errors);
        this.refreshTtl = parseTtl("REFRESH_TOKEN_TTL", jwt.refreshTtl(), "7d", errors);
        this.mediaTtl = parseTtl("MEDIA_TOKEN_TTL", jwt.mediaTtl(), "7d", errors);

        String root = blankToNull(props.storageRoot());
        this.storageRoot = (root != null
                ? Path.of(root)
                : Path.of(System.getProperty("user.dir"), "..", "server", "storage"))
                .toAbsolutePath().normalize();

        List<String> origins = new ArrayList<>();
        if (props.corsOrigins() != null) {
            Arrays.stream(props.corsOrigins().split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .forEach(origins::add);
        }
        this.corsOrigins = List.copyOf(origins);

        if (!errors.isEmpty()) {
            throw new IllegalStateException("Неверная конфигурация окружения (проверьте .env): " + String.join("; ", errors));
        }
    }

    private static void checkSecret(String name, String value, List<String> errors) {
        if (value == null) {
            errors.add(name + " обязателен: задайте его в .env");
        } else if (value.length() < 32) {
            errors.add(name + " должен быть не короче 32 символов");
        } else if (KNOWN_WEAK_SECRETS.contains(value)) {
            errors.add(name + " совпадает с известным значением по умолчанию");
        }
    }

    private static Duration parseTtl(String name, String value, String fallback, List<String> errors) {
        String raw = blankToNull(value);
        try {
            return TimeSpan.parse(raw == null ? fallback : raw);
        } catch (IllegalArgumentException e) {
            errors.add(name + ": " + e.getMessage());
            return Duration.ZERO;
        }
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    public String env() { return env; }
    public boolean isProduction() { return "production".equals(env); }
    public boolean isDevelopment() { return "development".equals(env); }
    public String databaseUrl() { return databaseUrl; }
    public boolean databaseSsl() { return databaseSsl; }
    public int databasePoolMax() { return databasePoolMax; }
    public String accessSecret() { return accessSecret; }
    public String refreshSecret() { return refreshSecret; }
    public Duration accessTtl() { return accessTtl; }
    public Duration refreshTtl() { return refreshTtl; }
    public Duration mediaTtl() { return mediaTtl; }
    public Path storageRoot() { return storageRoot; }
    public List<String> corsOrigins() { return corsOrigins; }
}
