package ru.mumusic.api.auth;

import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

/**
 * bcrypt с 10 раундами, как у пакета bcrypt в Node. Хеши $2b$ из старой базы проверяются,
 * новые хеши ($2a$) старый сервер тоже понимает. Как и в Node, учитываются первые 72 байта пароля.
 */
@Service
public class PasswordService {

    private static final int ROUNDS = 10;
    private static final int MAX_BYTES = 72;

    public String hash(String password) {
        return BCrypt.hashpw(bytes(password), BCrypt.gensalt(ROUNDS));
    }

    public boolean matches(String password, String hash) {
        if (hash == null || hash.isEmpty()) return false;
        try {
            return BCrypt.checkpw(bytes(password), hash);
        } catch (IllegalArgumentException e) {
            // Повреждённый или не-bcrypt хеш в базе
            return false;
        }
    }

    private static byte[] bytes(String password) {
        byte[] raw = password.getBytes(StandardCharsets.UTF_8);
        return raw.length > MAX_BYTES ? Arrays.copyOf(raw, MAX_BYTES) : raw;
    }
}
