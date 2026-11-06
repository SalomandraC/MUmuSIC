package ru.mumusic.api.security;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.Claim;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.springframework.stereotype.Service;
import ru.mumusic.api.config.AppConfig;

import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Выпуск и проверка JWT. Формат полностью совпадает с тем, что делал jsonwebtoken
 * в старом сервере (HS256, числовой sub, поле type), поэтому токены, выданные Node-версией,
 * продолжают работать и пользователей не выкинет из аккаунта.
 */
@Service
public class TokenService {

    public static final String TYPE_ACCESS = "access";
    public static final String TYPE_REFRESH = "refresh";
    public static final String TYPE_MEDIA = "media";

    private final Algorithm accessAlg;
    private final Algorithm refreshAlg;
    private final JWTVerifier accessVerifier;
    private final JWTVerifier refreshVerifier;
    private final Duration accessTtl;
    private final Duration refreshTtl;
    private final Duration mediaTtl;

    public TokenService(AppConfig config) {
        this.accessAlg = Algorithm.HMAC256(config.accessSecret());
        this.refreshAlg = Algorithm.HMAC256(config.refreshSecret());
        // jsonwebtoken не проверяет iat, только exp/nbf
        this.accessVerifier = JWT.require(accessAlg).ignoreIssuedAt().build();
        this.refreshVerifier = JWT.require(refreshAlg).ignoreIssuedAt().build();
        this.accessTtl = config.accessTtl();
        this.refreshTtl = config.refreshTtl();
        this.mediaTtl = config.mediaTtl();
    }

    /** Данные из проверенного токена */
    public record TokenPayload(long sub, String role, String type, String jti, String path, Instant expiresAt) {}

    public String generateAccessToken(long userId, String role, long tokenVersion) {
        return sign(basePayload(userId, role, tokenVersion, null), TYPE_ACCESS, accessAlg, accessTtl);
    }

    public String generateRefreshToken(long userId, String role, long tokenVersion, String jti) {
        return sign(basePayload(userId, role, tokenVersion, jti), TYPE_REFRESH, refreshAlg, refreshTtl);
    }

    /** Подпись для ссылки на личный файл: /storage/users/{id}/file.mp3?token=... */
    public String generateMediaToken(long userId, String filePath) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("sub", userId);
        payload.put("path", filePath);
        return sign(payload, TYPE_MEDIA, accessAlg, mediaTtl);
    }

    public TokenPayload verifyAccessToken(String token) {
        TokenPayload payload = verify(token, accessVerifier);
        if (!TYPE_ACCESS.equals(payload.type())) {
            throw new InvalidTokenException("Invalid access token type");
        }
        return payload;
    }

    public TokenPayload verifyRefreshToken(String token) {
        TokenPayload payload = verify(token, refreshVerifier);
        if (!TYPE_REFRESH.equals(payload.type())) {
            throw new InvalidTokenException("Invalid refresh token type");
        }
        return payload;
    }

    public TokenPayload verifyMediaToken(String token) {
        TokenPayload payload = verify(token, accessVerifier);
        if (!TYPE_MEDIA.equals(payload.type()) || payload.path() == null) {
            throw new InvalidTokenException("Invalid media token type");
        }
        return payload;
    }

    /** Момент истечения токена из поля exp (без проверки подписи) */
    public static Instant expiryOf(String token) {
        Date exp = JWT.decode(token).getExpiresAt();
        if (exp == null) throw new InvalidTokenException("Токен не содержит exp");
        return exp.toInstant();
    }

    private static Map<String, Object> basePayload(long userId, String role, long tokenVersion, String jti) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("sub", userId);
        payload.put("role", role);
        payload.put("tokenVersion", tokenVersion);
        if (jti != null) payload.put("jti", jti);
        return payload;
    }

    private static String sign(Map<String, Object> payload, String type, Algorithm alg, Duration ttl) {
        // Как jsonwebtoken: iat в секундах, exp = iat + floor(ttl в секундах)
        long iat = Instant.now().getEpochSecond();
        long exp = (long) Math.floor(iat + ttl.toMillis() / 1000.0);
        Map<String, Object> claims = new LinkedHashMap<>(payload);
        claims.put("type", type);
        claims.put("iat", iat);
        claims.put("exp", exp);
        return JWT.create().withPayload(claims).sign(alg);
    }

    private static TokenPayload verify(String token, JWTVerifier verifier) {
        DecodedJWT jwt;
        try {
            jwt = verifier.verify(token);
        } catch (com.auth0.jwt.exceptions.TokenExpiredException e) {
            throw new TokenExpiredException(e.getExpiredOn());
        } catch (JWTVerificationException | IllegalArgumentException e) {
            throw new InvalidTokenException(e.getMessage());
        }
        String type = jwt.getClaim("type").asString();
        if (type == null) {
            throw new InvalidTokenException("Токен не содержит тип");
        }
        Date exp = jwt.getExpiresAt();
        return new TokenPayload(
                subOf(jwt.getClaim("sub")),
                jwt.getClaim("role").asString(),
                type,
                jwt.getClaim("jti").asString(),
                jwt.getClaim("path").asString(),
                exp == null ? null : exp.toInstant()
        );
    }

    /** sub бывает числом (так выдавал jsonwebtoken) или строкой; 0 — нет пользователя */
    private static long subOf(Claim claim) {
        if (claim == null || claim.isMissing() || claim.isNull()) return 0;
        Long asLong = claim.asLong();
        if (asLong != null) return asLong;
        Double asDouble = claim.asDouble();
        if (asDouble != null) return asDouble == Math.rint(asDouble) ? asDouble.longValue() : 0;
        String asString = claim.asString();
        if (asString != null) {
            try {
                return Long.parseLong(asString.trim());
            } catch (NumberFormatException ignored) {
                return 0;
            }
        }
        return 0;
    }

    public static class InvalidTokenException extends RuntimeException {
        public InvalidTokenException(String message) { super(message); }
    }

    public static class TokenExpiredException extends InvalidTokenException {
        private final Instant expiredAt;

        public TokenExpiredException(Instant expiredAt) {
            super("jwt expired");
            this.expiredAt = expiredAt;
        }

        public Instant expiredAt() { return expiredAt; }
    }
}
