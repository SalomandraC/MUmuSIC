package ru.mumusic.api.common;

import java.util.List;
import java.util.Map;

/** Аналог ZodError: 400 {"error": "Ошибка валидации", "issues": [...]} */
public class ValidationException extends RuntimeException {

    private final List<Map<String, Object>> issues;

    public ValidationException(List<Map<String, Object>> issues) {
        super("Ошибка валидации");
        this.issues = issues;
    }

    public List<Map<String, Object>> issues() { return issues; }
}
