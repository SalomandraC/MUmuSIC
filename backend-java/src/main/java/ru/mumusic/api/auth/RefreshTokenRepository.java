package ru.mumusic.api.auth;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import ru.mumusic.api.common.Db;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Optional;

/** refresh_tokens: сам токен не хранится, только sha256 от него */
@Repository
public class RefreshTokenRepository {

    public record RefreshTokenRecord(long id, long userId, Instant expiresAt, Instant revokedAt) {}

    private final JdbcTemplate jdbc;

    public RefreshTokenRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public static String hashToken(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public long create(long userId, String token, Instant expiresAt, String device) {
        Long id = jdbc.queryForObject(
                "INSERT INTO refresh_tokens (user_id, token_hash, device, expires_at) VALUES (?, ?, ?, ?) RETURNING id",
                Long.class, userId, hashToken(token), device, Timestamp.from(expiresAt));
        return id == null ? 0 : id;
    }

    public Optional<RefreshTokenRecord> findByToken(String token) {
        return jdbc.query(
                "SELECT id, user_id, expires_at, revoked_at FROM refresh_tokens WHERE token_hash = ? LIMIT 1",
                (rs, i) -> new RefreshTokenRecord(
                        rs.getLong("id"),
                        rs.getLong("user_id"),
                        Db.instant(rs, "expires_at"),
                        Db.instant(rs, "revoked_at")),
                hashToken(token)).stream().findFirst();
    }

    /**
     * Атомарно отзывает активный токен. false — токен уже отозван:
     * так два параллельных refresh с одним токеном не получат две новые пары.
     */
    public boolean revokeIfActive(long id) {
        return !jdbc.queryForList(
                "UPDATE refresh_tokens SET revoked_at = now() WHERE id = ? AND revoked_at IS NULL RETURNING id",
                Long.class, id).isEmpty();
    }

    public void setReplacedBy(long id, long replacedBy) {
        jdbc.update("UPDATE refresh_tokens SET replaced_by = ? WHERE id = ?", replacedBy, id);
    }

    public int revokeAllForUser(long userId) {
        return jdbc.queryForList(
                "UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = ? AND revoked_at IS NULL RETURNING id",
                Long.class, userId).size();
    }

    public int deleteExpired() {
        return jdbc.update("DELETE FROM refresh_tokens WHERE expires_at < now() - interval '1 day'");
    }
}
