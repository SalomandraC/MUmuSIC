package ru.mumusic.api.auth;

import java.time.Instant;

/** Строка таблицы users */
public record User(
        long id,
        String username,
        String email,
        String passwordHash,
        String role,
        String guestSessionId,
        Instant createdAt,
        Instant updatedAt
) {}
