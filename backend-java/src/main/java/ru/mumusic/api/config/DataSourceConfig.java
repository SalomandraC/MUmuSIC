package ru.mumusic.api.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

/**
 * Пул соединений из DATABASE_URL в формате postgres://user:pass@host:port/db,
 * как у старого сервера (postgres.js). Spring ждёт JDBC-URL, поэтому переводим сами.
 */
@Configuration
public class DataSourceConfig {

    @Bean(destroyMethod = "close")
    public DataSource dataSource(AppConfig config) {
        JdbcUrl url = toJdbc(config.databaseUrl(), config.databaseSsl());

        HikariConfig hikari = new HikariConfig();
        hikari.setPoolName("mumusic-db");
        hikari.setJdbcUrl(url.jdbcUrl());
        if (url.user() != null) hikari.setUsername(url.user());
        if (url.password() != null) hikari.setPassword(url.password());
        hikari.setMaximumPoolSize(config.databasePoolMax());
        hikari.setMinimumIdle(Math.min(2, config.databasePoolMax()));
        hikari.setConnectionTimeout(30_000);
        return new HikariDataSource(hikari);
    }

    public record JdbcUrl(String jdbcUrl, String user, String password) {}

    public static JdbcUrl toJdbc(String databaseUrl, boolean ssl) {
        if (databaseUrl.startsWith("jdbc:")) {
            return new JdbcUrl(databaseUrl, null, null);
        }
        URI uri = URI.create(databaseUrl);
        String scheme = uri.getScheme();
        if (!"postgres".equals(scheme) && !"postgresql".equals(scheme)) {
            throw new IllegalStateException("DATABASE_URL должен начинаться с postgres:// или jdbc:postgresql://");
        }

        String user = null;
        String password = null;
        String userInfo = uri.getRawUserInfo();
        if (userInfo != null) {
            int colon = userInfo.indexOf(':');
            user = decode(colon >= 0 ? userInfo.substring(0, colon) : userInfo);
            password = colon >= 0 ? decode(userInfo.substring(colon + 1)) : null;
        }

        String host = uri.getHost() == null ? "localhost" : uri.getHost();
        int port = uri.getPort() == -1 ? 5432 : uri.getPort();
        String path = uri.getRawPath() == null || uri.getRawPath().isEmpty() ? "/postgres" : uri.getRawPath();

        StringBuilder jdbc = new StringBuilder("jdbc:postgresql://")
                .append(host).append(':').append(port).append(path)
                .append("?ApplicationName=mumusic-api");
        if (ssl) {
            // Как rejectUnauthorized: false в postgres.js: шифруем, сертификат не проверяем (Supabase)
            jdbc.append("&sslmode=require&sslfactory=org.postgresql.ssl.NonValidatingFactory");
        } else {
            jdbc.append("&sslmode=disable");
        }
        return new JdbcUrl(jdbc.toString(), user, password);
    }

    private static String decode(String value) {
        return URLDecoder.decode(value.replace("+", "%2B"), StandardCharsets.UTF_8);
    }
}
