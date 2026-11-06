package ru.mumusic.api.tracks;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;
import ru.mumusic.api.common.Db;

import java.util.List;
import java.util.Optional;

@Repository
public class TrackRepository {

    static final RowMapper<Track> MAPPER = (rs, i) -> new Track(
            rs.getLong("id"),
            rs.getLong("user_id"),
            rs.getString("title"),
            rs.getString("artist"),
            rs.getString("album"),
            Db.intOrNull(rs, "duration"),
            rs.getString("file_path"),
            rs.getString("file_format"),
            rs.getString("file_size"),
            rs.getString("notes"),
            rs.getBoolean("is_public"),
            rs.getInt("play_count"),
            Db.instant(rs, "created_at")
    );

    private final JdbcTemplate jdbc;

    public TrackRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public record NewTrack(String title, String artist, String album, Integer duration, String notes, boolean isPublic) {}

    public Track create(long userId, NewTrack t, String filePath, String fileFormat, long fileSize) {
        return jdbc.queryForObject("""
                INSERT INTO tracks (user_id, title, artist, album, duration, file_path, file_format, file_size, notes, is_public)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                RETURNING *
                """, MAPPER,
                userId, t.title(), t.artist(), t.album(), t.duration(), filePath, fileFormat, fileSize, t.notes(), t.isPublic());
    }

    public Optional<Track> findById(long id) {
        return jdbc.query("SELECT * FROM tracks WHERE id = ? LIMIT 1", MAPPER, id).stream().findFirst();
    }

    public List<Track> findByUserId(long userId) {
        return jdbc.query("""
                SELECT * FROM tracks
                WHERE user_id = ? AND file_format != 'metadata'
                ORDER BY created_at DESC
                """, MAPPER, userId);
    }

    public boolean delete(long id, long userId) {
        return !jdbc.queryForList("DELETE FROM tracks WHERE id = ? AND user_id = ? RETURNING id", Long.class, id, userId)
                .isEmpty();
    }
}
