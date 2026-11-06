package ru.mumusic.api.auth;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class PasswordServiceTest {

    private final PasswordService passwords = new PasswordService();

    @Test
    void проверяетХешиИзСтаройБазы() {
        // bcrypt из Node: префикс $2b$
        assertThat(passwords.matches("password123", "$2b$10$a2ibVoamjcTvjc8bHZJboeidqWtiXdxmhDXhzvxevyoCVd29pR2qe")).isTrue();
        assertThat(passwords.matches("password124", "$2b$10$a2ibVoamjcTvjc8bHZJboeidqWtiXdxmhDXhzvxevyoCVd29pR2qe")).isFalse();
        // Пароль длиннее 72 байт (кириллица): Node учитывал только первые 72 байта
        assertThat(passwords.matches("п".repeat(50), "$2b$10$FBgdxWvGlRQXKe.ihTvzA.j.vrYkA.0id90wAI3K5XoJLvYd6Cd0q")).isTrue();
    }

    @Test
    void новыйХешПроверяется() {
        String hash = passwords.hash("secret-pass");
        assertThat(passwords.matches("secret-pass", hash)).isTrue();
        assertThat(passwords.matches("other", hash)).isFalse();
        assertThat(passwords.matches("x", null)).isFalse();
        assertThat(passwords.matches("x", "not-a-hash")).isFalse();
    }
}
