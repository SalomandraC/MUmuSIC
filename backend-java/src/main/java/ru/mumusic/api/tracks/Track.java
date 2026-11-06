package ru.mumusic.api.tracks;

import java.time.Instant;

/** Строка таблицы tracks. fileSize строкой: bigint в старом сервере приходил в JSON строкой */
public record Track(
        long id,
        long userId,
        String title,
        String artist,
        String album,
        Integer duration,
        String filePath,
        String fileFormat,
        String fileSize,
        String notes,
        boolean isPublic,
        int playCount,
        Instant createdAt
) {}
