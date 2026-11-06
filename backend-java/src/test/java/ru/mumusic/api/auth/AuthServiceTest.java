package ru.mumusic.api.auth;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionCallback;
import org.springframework.transaction.support.TransactionTemplate;
import ru.mumusic.api.TestConfigs;
import ru.mumusic.api.common.HttpError;
import ru.mumusic.api.security.TokenService;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Ротация refresh-токенов и logout (порт auth.service.test.ts) */
class AuthServiceTest {

    private final User user = new User(7, "musicfan", "fan@example.com", "hash", "user", null,
            Instant.parse("2026-01-01T00:00:00Z"), Instant.parse("2026-01-01T00:00:00Z"));

    private UserRepository users;
    private RefreshTokenRepository repo;
    private TokenService tokens;
    private AuthService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        users = mock(UserRepository.class);
        repo = mock(RefreshTokenRepository.class);
        tokens = new TokenService(TestConfigs.config());
        TransactionTemplate tx = mock(TransactionTemplate.class);
        when(tx.execute(any())).thenAnswer(inv -> ((TransactionCallback<Object>) inv.getArgument(0)).doInTransaction(null));
        service = new AuthService(users, repo, mock(PasswordService.class), tokens, tx);

        when(users.findById(7)).thenReturn(Optional.of(user));
        when(repo.create(anyLong(), anyString(), any(), any())).thenReturn(101L);
    }

    private String oldRefresh() {
        return tokens.generateRefreshToken(7, "user", 1, "old");
    }

    @Test
    void отзываетСтарыйТокенВыдаётНовуюПаруИСвязываетЗаписи() {
        String old = oldRefresh();
        when(repo.findByToken(old)).thenReturn(Optional.of(
                new RefreshTokenRepository.RefreshTokenRecord(100, 7, Instant.now().plusSeconds(1000), null)));
        when(repo.revokeIfActive(100)).thenReturn(true);

        AuthDtos.Tokens result = service.refresh(old, "test-agent");

        assertThat(tokens.verifyAccessToken(result.accessToken()).sub()).isEqualTo(7);
        verify(repo).create(eq(7L), eq(result.refreshToken()), any(), eq("test-agent"));
        verify(repo).setReplacedBy(100, 101);
    }

    @Test
    void параллельныйRefreshПолучает401() {
        String old = oldRefresh();
        when(repo.findByToken(old)).thenReturn(Optional.of(
                new RefreshTokenRepository.RefreshTokenRecord(100, 7, Instant.now().plusSeconds(1000), null)));
        when(repo.revokeIfActive(100)).thenReturn(false);

        assertThatThrownBy(() -> service.refresh(old, null)).isInstanceOf(HttpError.class)
                .satisfies(e -> assertThat(((HttpError) e).status()).isEqualTo(401));
        verify(repo, never()).setReplacedBy(anyLong(), anyLong());
    }

    @Test
    void повторТолькоЧтоОтозванногоТокенаНеОтзываетВсеСессии() {
        String old = oldRefresh();
        when(repo.findByToken(old)).thenReturn(Optional.of(
                new RefreshTokenRepository.RefreshTokenRecord(100, 7, Instant.now().plusSeconds(1000), Instant.now())));

        assertThatThrownBy(() -> service.refresh(old, null)).isInstanceOf(HttpError.class);
        verify(repo, never()).revokeAllForUser(anyLong());
    }

    @Test
    void повторДавноОтозванногоТокенаОтзываетВсеСессии() {
        String old = oldRefresh();
        when(repo.findByToken(old)).thenReturn(Optional.of(
                new RefreshTokenRepository.RefreshTokenRecord(100, 7, Instant.now().plusSeconds(1000),
                        Instant.now().minusSeconds(60))));

        assertThatThrownBy(() -> service.refresh(old, null)).isInstanceOf(HttpError.class);
        verify(repo).revokeAllForUser(7);
    }

    @Test
    void токенСтарогоФорматаБезJtiОбменивается() {
        String legacy = tokens.generateRefreshToken(7, "user", 1, null);
        AuthDtos.Tokens result = service.refresh(legacy, null);
        assertThat(result.refreshToken()).isNotEqualTo(legacy);
        verify(repo, never()).findByToken(anyString());
    }

    @Test
    void чужойТокенВБазеОтклоняется() {
        String old = oldRefresh();
        when(repo.findByToken(old)).thenReturn(Optional.of(
                new RefreshTokenRepository.RefreshTokenRecord(100, 8, Instant.now().plusSeconds(1000), null)));
        assertThatThrownBy(() -> service.refresh(old, null)).isInstanceOf(HttpError.class);
    }

    @Test
    void logoutБезТокенаНичегоНеОтзывает() {
        assertThat(service.logout(null, false)).containsEntry("message", "Выход выполнен");
        verify(repo, never()).revokeAllForUser(anyLong());
    }

    @Test
    void logoutСоВсехУстройств() {
        when(repo.revokeAllForUser(7)).thenReturn(3);
        assertThat(service.logout(oldRefresh(), true))
                .containsEntry("message", "Выход выполнен на всех устройствах")
                .containsEntry("revoked", 3);
    }
}
