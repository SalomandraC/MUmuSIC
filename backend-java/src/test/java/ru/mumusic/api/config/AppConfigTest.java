package ru.mumusic.api.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AppConfigTest {

    private static AppProperties props(String access, String refresh, String dbUrl) {
        return new AppProperties("production", new AppProperties.Database(dbUrl, null, null),
                new AppProperties.Jwt(access, refresh, null, null, null), null, "https://a.ru, https://b.ru");
    }

    @Test
    void слабыеИлиОдинаковыеСекретыНеПринимаются() {
        String ok = "x".repeat(40);
        assertThatThrownBy(() -> new AppConfig(props("short", ok, "postgres://h/db"))).hasMessageContaining("не короче 32");
        assertThatThrownBy(() -> new AppConfig(props(ok, ok, "postgres://h/db"))).hasMessageContaining("должны различаться");
        assertThatThrownBy(() -> new AppConfig(props(ok, "y".repeat(40), null))).hasMessageContaining("DATABASE_URL");
    }

    @Test
    void значенияПоУмолчанию() {
        AppConfig config = new AppConfig(props("x".repeat(40), "y".repeat(40), "postgres://h/db"));
        assertThat(config.databaseSsl()).isTrue();
        assertThat(config.corsOrigins()).containsExactly("https://a.ru", "https://b.ru");
        assertThat(config.accessTtl().toMinutes()).isEqualTo(60);
    }

    @Test
    void databaseUrlВJdbc() {
        var url = DataSourceConfig.toJdbc("postgres://mumusic:p%40ss@postgres:5432/mumusic", false);
        assertThat(url.jdbcUrl()).isEqualTo("jdbc:postgresql://postgres:5432/mumusic?ApplicationName=mumusic-api&sslmode=disable");
        assertThat(url.user()).isEqualTo("mumusic");
        assertThat(url.password()).isEqualTo("p@ss");
    }
}
