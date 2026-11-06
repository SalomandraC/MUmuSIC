package ru.mumusic.api.security;

/** Пользователь из access-токена (аналог req.user в Express) */
public record AuthUser(long id, String role) {}
