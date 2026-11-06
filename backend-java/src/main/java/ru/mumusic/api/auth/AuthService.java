package ru.mumusic.api.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import ru.mumusic.api.auth.AuthDtos.AuthResult;
import ru.mumusic.api.auth.AuthDtos.SafeUser;
import ru.mumusic.api.auth.AuthDtos.Tokens;
import ru.mumusic.api.common.HttpError;
import ru.mumusic.api.security.TokenService;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** Повтор только что отозванного токена в этом окне считаем параллельным refresh, а не кражей */
    static final long REUSE_GRACE_MS = 30_000;

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordService passwords;
    private final TokenService tokens;
    private final TransactionTemplate tx;

    public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, PasswordService passwords,
                       TokenService tokens, TransactionTemplate tx) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwords = passwords;
        this.tokens = tokens;
        this.tx = tx;
    }

    record Issued(Tokens tokens, long refreshId) {}

    /** Выпускает пару токенов и сохраняет sha256 refresh-токена в refresh_tokens */
    Issued issueTokens(User user, String device) {
        long tokenVersion = user.updatedAt() != null ? user.updatedAt().toEpochMilli() : System.currentTimeMillis();
        String refresh = tokens.generateRefreshToken(user.id(), user.role(), tokenVersion, UUID.randomUUID().toString());
        long refreshId = refreshTokens.create(user.id(), refresh, TokenService.expiryOf(refresh), device);
        String access = tokens.generateAccessToken(user.id(), user.role(), tokenVersion);
        return new Issued(new Tokens(access, refresh), refreshId);
    }

    public AuthResult register(AuthDtos.RegisterRequest input, String device) {
        boolean emailTaken = users.findByEmail(input.email()).isPresent();
        boolean usernameTaken = users.findByUsername(input.username()).isPresent();
        if (emailTaken) {
            throw new HttpError(409, "Пользователь с таким email уже существует");
        }
        if (usernameTaken) {
            throw new HttpError(409, "Пользователь с таким username уже существует");
        }

        String hash = passwords.hash(input.password());
        User user = users.create(input.username(), input.email().toLowerCase(Locale.ROOT).trim(), hash, "user");
        return new AuthResult(SafeUser.of(user), issueTokens(user, device).tokens());
    }

    public AuthResult login(AuthDtos.LoginRequest input, String device) {
        User user = users.findByEmail(input.email())
                .orElseThrow(() -> HttpError.unauthorized("Неверные учетные данные"));
        if (!passwords.matches(input.password(), user.passwordHash())) {
            throw HttpError.unauthorized("Неверные учетные данные");
        }
        return new AuthResult(SafeUser.of(user), issueTokens(user, device).tokens());
    }

    /**
     * Ротация: старый refresh-токен отзывается, выдаётся новая пара.
     * Повторное предъявление уже отозванного токена означает, что его, скорее всего,
     * украли: тогда отзываются все сессии пользователя.
     */
    public Tokens refresh(String refreshToken, String device) {
        TokenService.TokenPayload payload;
        try {
            payload = tokens.verifyRefreshToken(refreshToken);
        } catch (TokenService.InvalidTokenException e) {
            throw invalidToken();
        }

        long userId = payload.sub();
        if (userId == 0) throw invalidToken();

        User user = users.findById(userId).orElseThrow(() -> HttpError.notFound("Пользователь не найден"));

        // Токены, выданные до появления refresh_tokens, не содержат jti и не записаны в базу.
        // Их принимаем один раз и сразу меняем на новые, чтобы никого не выкинуло из аккаунта
        if (payload.jti() == null) {
            log.info("Обмен refresh-токена старого формата, userId={}", userId);
            return issueTokens(user, device).tokens();
        }

        RefreshTokenRepository.RefreshTokenRecord stored = refreshTokens.findByToken(refreshToken)
                .filter(r -> r.userId() == userId)
                .orElseThrow(AuthService::invalidToken);

        if (stored.revokedAt() != null) {
            // Токен отозван только что: скорее всего, второй параллельный refresh того же клиента
            if (System.currentTimeMillis() - stored.revokedAt().toEpochMilli() < REUSE_GRACE_MS) {
                throw invalidToken();
            }
            int revoked = refreshTokens.revokeAllForUser(userId);
            log.warn("Повторное использование отозванного refresh-токена, все сессии отозваны: userId={}, revoked={}",
                    userId, revoked);
            throw invalidToken();
        }

        if (!stored.expiresAt().isAfter(Instant.now())) {
            throw invalidToken();
        }

        return tx.execute(status -> {
            if (!refreshTokens.revokeIfActive(stored.id())) {
                // Параллельный запрос с тем же токеном успел первым
                throw invalidToken();
            }
            Issued issued = issueTokens(user, device);
            refreshTokens.setReplacedBy(stored.id(), issued.refreshId());
            return issued.tokens();
        });
    }

    public SafeUser profile(long userId) {
        return users.findById(userId).map(SafeUser::of)
                .orElseThrow(() -> HttpError.notFound("Пользователь не найден"));
    }

    /**
     * Отзывает refresh-токен текущего устройства или, с allDevices, все сессии пользователя.
     * Без refreshToken ничего не отзывается (старые версии приложения вызывают logout без тела).
     */
    public Map<String, Object> logout(String refreshToken, boolean allDevices) {
        Map<String, Object> done = new LinkedHashMap<>();
        done.put("message", "Выход выполнен");
        if (refreshToken == null) return done;

        TokenService.TokenPayload payload;
        try {
            payload = tokens.verifyRefreshToken(refreshToken);
        } catch (TokenService.InvalidTokenException e) {
            // Просроченный или чужой токен: выйти из него и так уже нельзя
            return done;
        }

        long userId = payload.sub();
        if (allDevices) {
            int revoked = refreshTokens.revokeAllForUser(userId);
            Map<String, Object> all = new LinkedHashMap<>();
            all.put("message", "Выход выполнен на всех устройствах");
            all.put("revoked", revoked);
            return all;
        }

        refreshTokens.findByToken(refreshToken)
                .filter(r -> r.userId() == userId)
                .ifPresent(r -> refreshTokens.revokeIfActive(r.id()));
        return done;
    }

    private static HttpError invalidToken() {
        return HttpError.unauthorized("Недействительный или отозванный refresh-токен");
    }
}
