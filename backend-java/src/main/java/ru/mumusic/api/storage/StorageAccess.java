package ru.mumusic.api.storage;

import java.nio.ByteBuffer;
import java.nio.CharBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * Правило доступа к файлам хранилища (порт storageGuard.ts):
 * users/{id}/... — только владельцу (access-токен или подписанная ссылка на этот файл),
 * всё остальное (общие треки гостей и NFC) — публично.
 */
public final class StorageAccess {

    public enum Access { PUBLIC, PRIVATE, DENY }

    /** userId — sub из access-токена; mediaSub/mediaPath — из подписанной ссылки ?token= */
    public record Credentials(Long userId, Long mediaSub, String mediaPath) {
        public static Credentials none() { return new Credentials(null, null, null); }
    }

    private StorageAccess() {}

    /**
     * Приводит путь запроса к виду внутри STORAGE_ROOT: 'users/3/track.mp3'.
     * null — путь некорректный (выход за корень, скрытые файлы вроде .tmp, битая кодировка).
     */
    public static String normalizePath(String rawPath) {
        String decoded = decodeUriComponent(rawPath);
        if (decoded == null) return null;
        if (decoded.indexOf('\0') >= 0 || decoded.indexOf('\\') >= 0) return null;

        String normalized = posixNormalizeAbsolute("/" + decoded).replaceFirst("^/+", "");
        if (normalized.isEmpty() || normalized.startsWith("..")) return null;

        for (String segment : normalized.split("/", -1)) {
            if (segment.startsWith(".")) return null;
        }
        return normalized;
    }

    public static Access resolve(String relPath, Credentials creds) {
        String[] segments = relPath.split("/", -1);
        if (!segments[0].equals("users")) return Access.PUBLIC;

        long ownerId = parseOwner(segments.length > 1 ? segments[1] : "");
        if (ownerId <= 0 || segments.length < 3) return Access.DENY;

        if (creds.userId() != null && creds.userId() == ownerId) return Access.PRIVATE;
        if (creds.mediaSub() != null && creds.mediaSub() == ownerId && relPath.equals(creds.mediaPath())) {
            return Access.PRIVATE;
        }
        return Access.DENY;
    }

    /** Number(segment) в JS: только целое положительное, иначе 0 */
    private static long parseOwner(String segment) {
        try {
            double value = Double.parseDouble(segment.trim());
            if (segment.isBlank() || value != Math.rint(value) || Double.isInfinite(value)) return 0;
            return (long) value;
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** decodeURIComponent: %XX — байты UTF-8, '+' остаётся плюсом; битая последовательность → null */
    static String decodeUriComponent(String value) {
        if (value.indexOf('%') < 0) return value;
        StringBuilder out = new StringBuilder();
        ByteBuffer bytes = ByteBuffer.allocate(value.length());
        CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
        int i = 0;
        while (i < value.length()) {
            char c = value.charAt(i);
            if (c == '%') {
                if (i + 2 >= value.length()) return null;
                int hi = Character.digit(value.charAt(i + 1), 16);
                int lo = Character.digit(value.charAt(i + 2), 16);
                if (hi < 0 || lo < 0) return null;
                bytes.put((byte) ((hi << 4) | lo));
                i += 3;
            } else {
                if (!flush(bytes, decoder, out)) return null;
                out.append(c);
                i++;
            }
        }
        if (!flush(bytes, decoder, out)) return null;
        return out.toString();
    }

    private static boolean flush(ByteBuffer bytes, CharsetDecoder decoder, StringBuilder out) {
        if (bytes.position() == 0) return true;
        bytes.flip();
        try {
            CharBuffer chars = decoder.reset().decode(bytes);
            out.append(chars);
        } catch (CharacterCodingException e) {
            return false;
        } finally {
            bytes.clear();
        }
        return true;
    }

    /** path.posix.normalize для абсолютного пути: убирает '.', '..', двойные слэши; сохраняет хвостовой '/' */
    static String posixNormalizeAbsolute(String path) {
        Deque<String> stack = new ArrayDeque<>();
        for (String part : path.split("/")) {
            if (part.isEmpty() || part.equals(".")) continue;
            if (part.equals("..")) {
                if (!stack.isEmpty()) stack.removeLast();
            } else {
                stack.addLast(part);
            }
        }
        List<String> parts = new ArrayList<>(stack);
        String result = "/" + String.join("/", parts);
        if (path.endsWith("/") && !parts.isEmpty()) result += "/";
        return result;
    }
}
