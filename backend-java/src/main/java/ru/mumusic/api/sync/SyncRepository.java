package ru.mumusic.api.sync;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import ru.mumusic.api.common.Db;
import ru.mumusic.api.common.JsonConfig;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Плейлисты приложения в таблицах playlists/playlist_tracks (playlist_type = 'sync').
 * Треки, которых нет у пользователя, сохраняются как записи tracks с file_format = 'metadata'.
 */
@Repository
public class SyncRepository {

    private static final Pattern TRACK_ID = Pattern.compile("trackId:\\s*(\\d+)");
    private static final Pattern PREVIEW = Pattern.compile("Preview:\\s*(.+)");

    private final JdbcTemplate jdbc;

    public SyncRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private record PlaylistRow(long id, String name, String description, Instant createdAt) {}

    private record TrackRow(Long trackId, int position, String title, String artist, Integer duration, String notes) {}

    public List<Map<String, Object>> getPlaylists(long userId) {
        List<PlaylistRow> playlists = jdbc.query("""
                SELECT id, name, description, created_at
                FROM playlists
                WHERE user_id = ? AND playlist_type = 'sync'
                ORDER BY created_at DESC
                """, (rs, i) -> new PlaylistRow(rs.getLong("id"), rs.getString("name"),
                rs.getString("description"), Db.instant(rs, "created_at")), userId);

        List<Map<String, Object>> result = new ArrayList<>();
        for (PlaylistRow playlist : playlists) {
            List<TrackRow> rows = jdbc.query("""
                    SELECT pt.track_id, pt.position, t.title, t.artist, t.duration, t.notes
                    FROM playlist_tracks pt
                    LEFT JOIN tracks t ON pt.track_id = t.id
                    WHERE pt.playlist_id = ?
                    ORDER BY pt.position ASC
                    """, (rs, i) -> {
                long trackId = rs.getLong("track_id");
                return new TrackRow(rs.wasNull() ? null : trackId, rs.getInt("position"), rs.getString("title"),
                        rs.getString("artist"), Db.intOrNull(rs, "duration"), rs.getString("notes"));
            }, playlist.id());

            List<Map<String, Object>> tracks = new ArrayList<>();
            for (int idx = 0; idx < rows.size(); idx++) {
                tracks.add(toPlaylistTrack(rows.get(idx), idx));
            }

            // Поля со значением undefined в JS в JSON не попадали — здесь их тоже нет
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("id", playlist.id());
            out.put("name", playlist.name());
            if (playlist.description() != null && !playlist.description().isEmpty()) {
                out.put("description", playlist.description());
            }
            out.put("tracks", tracks);
            String created = playlist.createdAt() == null ? null : JsonConfig.iso(playlist.createdAt());
            out.put("createdAt", created);
            out.put("updatedAt", created);
            result.add(out);
        }
        return result;
    }

    private static Map<String, Object> toPlaylistTrack(TrackRow pt, int idx) {
        Long trackId = null;
        String previewUrl = null;
        if (pt.notes() != null && !pt.notes().isEmpty()) {
            Matcher id = TRACK_ID.matcher(pt.notes());
            if (id.find()) {
                try {
                    trackId = Long.parseLong(id.group(1));
                } catch (NumberFormatException ignored) {
                    // слишком длинное число: оставим id записи
                }
            }
            Matcher preview = PREVIEW.matcher(pt.notes());
            if (preview.find()) {
                previewUrl = preview.group(1).trim();
            }
        }

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("trackId", trackId != null && trackId != 0 ? trackId : (pt.trackId() != null ? pt.trackId() : 0L));
        if (pt.title() != null && !pt.title().isEmpty()) out.put("trackName", pt.title());
        if (pt.artist() != null && !pt.artist().isEmpty()) out.put("artistName", pt.artist());
        if (pt.duration() != null && pt.duration() != 0) out.put("trackTimeMillis", pt.duration() * 1000L);
        out.put("artworkUrl100", null);
        out.put("previewUrl", previewUrl != null && !previewUrl.isEmpty() ? previewUrl : null);
        out.put("position", pt.position() != 0 ? pt.position() : idx);
        return out;
    }

    /** Полностью заменяет sync-плейлисты пользователя присланными */
    @Transactional
    public void savePlaylists(long userId, List<SyncDtos.Playlist> playlists) {
        List<Long> existing = jdbc.queryForList(
                "SELECT id FROM playlists WHERE user_id = ? AND playlist_type = 'sync'", Long.class, userId);
        for (Long id : existing) {
            jdbc.update("DELETE FROM playlist_tracks WHERE playlist_id = ?", id);
            jdbc.update("DELETE FROM playlists WHERE id = ?", id);
        }

        for (SyncDtos.Playlist playlist : playlists) {
            Long playlistId = jdbc.queryForObject("""
                    INSERT INTO playlists (user_id, name, description, playlist_type, nfc_uid, is_public)
                    VALUES (?, ?, ?, 'sync', null, false)
                    RETURNING id
                    """, Long.class, userId, playlist.name(), emptyToNull(playlist.description()));

            // Один трек в плейлисте — один раз
            Set<Long> inserted = new HashSet<>();
            List<SyncDtos.PlaylistTrack> tracks = playlist.tracks();
            for (int i = 0; i < tracks.size(); i++) {
                SyncDtos.PlaylistTrack track = tracks.get(i);
                Long trackRecordId = null;

                if (notEmpty(track.trackName()) && notEmpty(track.artistName())) {
                    trackRecordId = jdbc.queryForList("""
                            SELECT id FROM tracks
                            WHERE user_id = ? AND title = ? AND artist = ?
                            LIMIT 1
                            """, Long.class, userId, track.trackName(), track.artistName())
                            .stream().findFirst().orElse(null);
                }

                if (trackRecordId == null && notEmpty(track.trackName())) {
                    String jsTrackId = jsNumber(track.trackId());
                    String dummyPath = "playlists/" + userId + "/" + System.currentTimeMillis() + "_"
                            + track.trackName().replaceAll("[^a-zA-Z0-9._ -]", "_") + ".meta";
                    String notes = notEmpty(track.previewUrl())
                            ? "Из плейлиста (trackId: " + jsTrackId + ") | Preview: " + track.previewUrl()
                            : "Из плейлиста (trackId: " + jsTrackId + ")";
                    Integer duration = track.trackTimeMillis() != null && track.trackTimeMillis() != 0
                            && !track.trackTimeMillis().isNaN()
                            ? (int) Math.floor(track.trackTimeMillis() / 1000) : null;

                    trackRecordId = jdbc.queryForObject("""
                            INSERT INTO tracks (user_id, title, artist, duration, file_path, file_format, file_size, notes, is_public)
                            VALUES (?, ?, ?, ?, ?, 'metadata', 0, ?, false)
                            RETURNING id
                            """, Long.class, userId, track.trackName(), emptyToNull(track.artistName()), duration,
                            dummyPath, notes);
                }

                if (trackRecordId != null && inserted.add(trackRecordId)) {
                    jdbc.update("""
                            INSERT INTO playlist_tracks (playlist_id, track_id, position)
                            VALUES (?, ?, ?)
                            ON CONFLICT (playlist_id, track_id) DO UPDATE SET position = EXCLUDED.position
                            """, playlistId, trackRecordId, i);
                }
            }
        }
    }

    /** Число так, как его печатает JS: 5 вместо 5.0 */
    static String jsNumber(Double value) {
        if (value == null) return "undefined";
        if (value == Math.rint(value) && !value.isInfinite() && Math.abs(value) < 1e21) {
            return Long.toString(value.longValue());
        }
        return value.toString();
    }

    private static boolean notEmpty(String value) {
        return value != null && !value.isEmpty();
    }

    private static String emptyToNull(String value) {
        return value == null || value.isEmpty() ? null : value;
    }
}
