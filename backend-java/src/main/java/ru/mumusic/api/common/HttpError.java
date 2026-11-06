package ru.mumusic.api.common;

import java.util.LinkedHashMap;
import java.util.Map;

/** Ошибка с HTTP-статусом. Превращается в {"error": "..."} в {@link GlobalExceptionHandler}. */
public class HttpError extends RuntimeException {

    private final int status;
    /** Дополнительные поля ответа рядом с error (например, details) */
    private final Map<String, Object> extra;

    public HttpError(int status, String message) {
        this(status, message, Map.of());
    }

    public HttpError(int status, String message, Map<String, Object> extra) {
        super(message);
        this.status = status;
        this.extra = new LinkedHashMap<>(extra);
    }

    public int status() { return status; }
    public Map<String, Object> extra() { return extra; }

    public static HttpError notFound(String message) { return new HttpError(404, message); }
    public static HttpError badRequest(String message) { return new HttpError(400, message); }
    public static HttpError unauthorized(String message) { return new HttpError(401, message); }
}
