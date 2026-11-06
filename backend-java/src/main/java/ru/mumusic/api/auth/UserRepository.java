package ru.mumusic.api.auth;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import ru.mumusic.api.common.Db;

import java.util.Optional;

@Repository
public class UserRepository {

    private static final RowMapper<User> MAPPER = (rs, i) -> new User(
            rs.getLong("id"),
            rs.getString("username"),
            rs.getString("email"),
            rs.getString("password_hash"),
            rs.getString("role"),
            rs.getString("guest_session_id"),
            Db.instant(rs, "created_at"),
            Db.instant(rs, "updated_at")
    );

    private final JdbcTemplate jdbc;

    public UserRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<User> findByEmail(String email) {
        return jdbc.query("SELECT * FROM users WHERE lower(email) = lower(?) LIMIT 1", MAPPER, email)
                .stream().findFirst();
    }

    public Optional<User> findByUsername(String username) {
        return jdbc.query("SELECT * FROM users WHERE lower(username) = lower(?) LIMIT 1", MAPPER, username)
                .stream().findFirst();
    }

    public Optional<User> findById(long id) {
        return jdbc.query("SELECT * FROM users WHERE id = ? LIMIT 1", MAPPER, id).stream().findFirst();
    }

    public User create(String username, String email, String passwordHash, String role) {
        return jdbc.queryForObject(
                "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?) RETURNING *",
                MAPPER, username, email, passwordHash, role);
    }
}
