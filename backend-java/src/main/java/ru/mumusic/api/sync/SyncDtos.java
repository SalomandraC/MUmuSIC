package ru.mumusic.api.sync;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

/** Формат плейлистов приложения (схемы zod из sync.controller.ts) */
public final class SyncDtos {

    private SyncDtos() {}

    public record PlaylistTrack(
            @NotNull(message = "Обязательное поле") Double trackId,
            String trackName,
            String artistName,
            Double trackTimeMillis,
            String artworkUrl100,
            String previewUrl,
            @NotNull(message = "Обязательное поле") Double position
    ) {}

    public record Playlist(
            Double id,
            @NotNull(message = "Обязательное поле") String name,
            String description,
            String coverImageUri,
            @NotNull(message = "Обязательное поле") List<@Valid @NotNull PlaylistTrack> tracks
    ) {}

    public record SyncData(@NotNull(message = "Обязательное поле") List<@Valid @NotNull Playlist> playlists) {}
}
