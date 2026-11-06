package ru.mumusic.api.storage;

import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;

import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/** MIME-тип по расширению, с теми же значениями, что давал пакет mime-types в Node */
public final class MimeTypes {

    private static final Map<String, String> AUDIO = Map.of(
            "mp3", "audio/mpeg",
            "m4a", "audio/mp4",
            "wav", "audio/wave",
            "flac", "audio/x-flac",
            "ogg", "audio/ogg",
            "aac", "audio/x-aac",
            "opus", "audio/ogg",
            "mp4", "video/mp4"
    );

    private MimeTypes() {}

    /** Принимает "mp3", ".mp3" или имя файла. Пусто, если тип неизвестен (как false из mime.lookup) */
    public static Optional<String> lookup(String extOrName) {
        if (extOrName == null || extOrName.isEmpty()) return Optional.empty();
        String value = extOrName.toLowerCase(Locale.ROOT);
        int dot = value.lastIndexOf('.');
        String ext = dot >= 0 ? value.substring(dot + 1) : value;
        String known = AUDIO.get(ext);
        if (known != null) return Optional.of(known);
        return MediaTypeFactory.getMediaType("file." + ext).map(MediaType::toString);
    }
}
