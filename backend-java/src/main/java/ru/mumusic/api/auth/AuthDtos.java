package ru.mumusic.api.auth;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/** Тела запросов и ответов /auth. Правила те же, что в auth.validators.ts (zod) */
public final class AuthDtos {

    private AuthDtos() {}

    /** Регулярка z.string().email() из zod */
    static final String EMAIL_REGEX =
            "^(?!\\.)(?!.*\\.\\.)([A-Za-z0-9_'+\\-\\.]*)[A-Za-z0-9_+-]@([A-Za-z0-9][A-Za-z0-9\\-]*\\.)+[A-Za-z]{2,}$";

    public record RegisterRequest(
            @NotNull(message = "Обязательное поле") @Size(min = 3, max = 50) String username,
            @NotNull(message = "Обязательное поле") @Pattern(regexp = EMAIL_REGEX, message = "Некорректный email") String email,
            @NotNull(message = "Обязательное поле") @Size(min = 8, max = 100) String password
    ) {}

    public record LoginRequest(
            @NotNull(message = "Обязательное поле") @Pattern(regexp = EMAIL_REGEX, message = "Некорректный email") String email,
            @NotNull(message = "Обязательное поле") @Size(min = 8, max = 100) String password
    ) {}

    public record RefreshRequest(
            @NotNull(message = "Обязательное поле") @Size(min = 10) String refreshToken
    ) {}

    public record LogoutRequest(
            @Size(min = 10) String refreshToken,
            Boolean allDevices
    ) {}

    public record Tokens(String accessToken, String refreshToken) {}

    public record SafeUser(
            long id,
            String username,
            String email,
            String role,
            String guestSessionId,
            Instant createdAt,
            Instant updatedAt
    ) {
        static SafeUser of(User u) {
            return new SafeUser(u.id(), u.username(), u.email(), u.role(), u.guestSessionId(), u.createdAt(), u.updatedAt());
        }
    }

    public record AuthResult(SafeUser user, Tokens tokens) {}
}
