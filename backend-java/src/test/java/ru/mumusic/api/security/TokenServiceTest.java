package ru.mumusic.api.security;

import org.junit.jupiter.api.Test;
import ru.mumusic.api.TestConfigs;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TokenServiceTest {

    /** Выпущены старым сервером (jsonwebtoken) с тем же секретом, срок 100 лет */
    static final String NODE_ACCESS = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjcsInJvbGUiOiJ1c2VyIiwidG9rZW5WZXJzaW9uIjoxNzY3MjI1NjAwMDAwLCJ0eXBlIjoiYWNjZXNzIiwiaWF0IjoxNzkzODk5NjYzLCJleHAiOjQ5NDk2NTk2NjN9.Ff1nwZP7i1GcrOC99mZ_KFSQRANCe6_SMr-gXxIFqes";
    static final String NODE_MEDIA = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjMsInBhdGgiOiJ1c2Vycy8zL2EubXAzIiwidHlwZSI6Im1lZGlhIiwiaWF0IjoxNzkzODk5NjYzLCJleHAiOjQ5NDk2NTk2NjN9.xn_6t3zDVEiXpSautN460SS3u5MVqyiBStuDxXUK7ko";

    private final TokenService tokens = new TokenService(TestConfigs.config());

    @Test
    void принимаетТокеныСтарогоСервера() {
        TokenService.TokenPayload access = tokens.verifyAccessToken(NODE_ACCESS);
        assertThat(access.sub()).isEqualTo(7);
        assertThat(access.role()).isEqualTo("user");

        TokenService.TokenPayload media = tokens.verifyMediaToken(NODE_MEDIA);
        assertThat(media.sub()).isEqualTo(3);
        assertThat(media.path()).isEqualTo("users/3/a.mp3");
    }

    @Test
    void выпускаетИПроверяетСвоиТокены() {
        String access = tokens.generateAccessToken(5, "admin", 123);
        assertThat(tokens.verifyAccessToken(access).sub()).isEqualTo(5);

        String refresh = tokens.generateRefreshToken(5, "admin", 123, "jti-1");
        TokenService.TokenPayload payload = tokens.verifyRefreshToken(refresh);
        assertThat(payload.jti()).isEqualTo("jti-1");
        assertThat(payload.expiresAt()).isEqualTo(TokenService.expiryOf(refresh));
    }

    @Test
    void типТокенаПроверяется() {
        String media = tokens.generateMediaToken(3, "users/3/a.mp3");
        String access = tokens.generateAccessToken(3, "user", 1);
        assertThatThrownBy(() -> tokens.verifyAccessToken(media)).isInstanceOf(TokenService.InvalidTokenException.class);
        assertThatThrownBy(() -> tokens.verifyMediaToken(access)).isInstanceOf(TokenService.InvalidTokenException.class);
        // refresh подписан другим секретом
        assertThatThrownBy(() -> tokens.verifyRefreshToken(access)).isInstanceOf(TokenService.InvalidTokenException.class);
    }

    @Test
    void просроченныйТокенДаётTokenExpired() {
        TokenService shortLived = new TokenService(TestConfigs.config("1ms"));
        String token = shortLived.generateAccessToken(1, "user", 1);
        assertThatThrownBy(() -> shortLived.verifyAccessToken(token))
                .isInstanceOf(TokenService.TokenExpiredException.class)
                .satisfies(e -> assertThat(((TokenService.TokenExpiredException) e).expiredAt()).isNotNull());
    }

    @Test
    void подделанныйТокенОтклоняется() {
        String forged = NODE_ACCESS.substring(0, NODE_ACCESS.length() - 2) + "xx";
        assertThatThrownBy(() -> tokens.verifyAccessToken(forged)).isInstanceOf(TokenService.InvalidTokenException.class);
        assertThatThrownBy(() -> tokens.verifyAccessToken("garbage")).isInstanceOf(TokenService.InvalidTokenException.class);
    }
}
