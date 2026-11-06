package ru.mumusic.api.common;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import ru.mumusic.api.config.AppConfig;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Единый формат ошибок, как у errorHandler/notFoundHandler старого сервера:
 * {"error": "..."}; в development дополнительно stack.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private final AppConfig config;

    public GlobalExceptionHandler(AppConfig config) {
        this.config = config;
    }

    @ExceptionHandler(HttpError.class)
    public ResponseEntity<Object> httpError(HttpError e, HttpServletRequest req) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", e.getMessage());
        body.putAll(e.extra());
        return respond(e.status(), body, e, req);
    }

    @ExceptionHandler(ValidationException.class)
    public ResponseEntity<Object> validation(ValidationException e, HttpServletRequest req) {
        return validationResponse(e.issues(), e, req);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Object> beanValidation(MethodArgumentNotValidException e, HttpServletRequest req) {
        List<Map<String, Object>> issues = e.getBindingResult().getFieldErrors().stream()
                .map(fe -> ValidationIssues.issue(List.of(fe.getField()), fe.getDefaultMessage()))
                .toList();
        return validationResponse(issues, new ValidationException(issues), req);
    }

    /** Битый JSON, неверные типы полей, пустое тело там, где оно обязательно */
    @ExceptionHandler({HttpMessageNotReadableException.class, HttpMediaTypeNotSupportedException.class})
    public ResponseEntity<Object> unreadable(Exception e, HttpServletRequest req) {
        String detail = e instanceof HttpMessageNotReadableException ? "Некорректное тело запроса" : e.getMessage();
        List<Map<String, Object>> issues = List.of(ValidationIssues.issue(List.of(), detail));
        return validationResponse(issues, new ValidationException(issues), req);
    }

    @ExceptionHandler(DuplicateKeyException.class)
    public ResponseEntity<Object> duplicate(DuplicateKeyException e, HttpServletRequest req) {
        // Гонка двух одновременных регистраций: проверка в сервисе прошла у обоих, базу — только один
        return respond(409, Map.of("error", "Пользователь с таким email или username уже существует"), e, req);
    }

    /** Имя файла, которое нельзя представить в файловой системе сервера */
    @ExceptionHandler(java.nio.file.InvalidPathException.class)
    public ResponseEntity<Object> invalidPath(java.nio.file.InvalidPathException e, HttpServletRequest req) {
        log.warn("Недопустимый путь {}: {}", req.getRequestURI(), e.getMessage());
        return ResponseEntity.status(404).body(Map.of("error", "Файл не найден"));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<Object> tooLarge(MaxUploadSizeExceededException e, HttpServletRequest req) {
        return respond(413, Map.of("error", "Файл слишком большой (максимум 100 МБ)"), e, req);
    }

    @ExceptionHandler({NoHandlerFoundException.class, NoResourceFoundException.class, HttpRequestMethodNotSupportedException.class})
    public ResponseEntity<Object> notFound(Exception e, HttpServletRequest req) {
        return ResponseEntity.status(404).body(notFoundBody(req));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Object> internal(Exception e, HttpServletRequest req, HttpServletResponse res) {
        if (isClientAbort(e) || res.isCommitted()) {
            // Клиент закрыл соединение посреди стрима: отвечать уже некому
            log.debug("Соединение закрыто клиентом: {} {}", req.getMethod(), req.getRequestURI());
            return null;
        }
        String message = e.getMessage() == null ? "Внутренняя ошибка сервера" : e.getMessage();
        Map<String, Object> body = new LinkedHashMap<>();
        // Текст внутренних ошибок (SQL, файловая система) клиенту в production не показываем
        body.put("error", config.isProduction() ? "Внутренняя ошибка сервера" : message);
        return respond(500, body, e, req);
    }

    public static Map<String, Object> notFoundBody(HttpServletRequest req) {
        String path = req.getRequestURI();
        return Map.of("error", "Маршрут " + req.getMethod() + " " + path + " не найден");
    }

    private ResponseEntity<Object> validationResponse(List<Map<String, Object>> issues, Exception e, HttpServletRequest req) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", "Ошибка валидации");
        body.put("issues", issues);
        return respond(400, body, e, req);
    }

    private ResponseEntity<Object> respond(int status, Map<String, Object> body, Exception e, HttpServletRequest req) {
        if (status >= 500) {
            log.error("{} {} → {}", req.getMethod(), req.getRequestURI(), e.toString(), e);
        } else {
            log.warn("{} {} → {} {}", req.getMethod(), req.getRequestURI(), status, e.getMessage());
        }
        Map<String, Object> out = new LinkedHashMap<>(body);
        if (config.isDevelopment()) {
            StringWriter sw = new StringWriter();
            e.printStackTrace(new PrintWriter(sw));
            out.put("stack", sw.toString());
        }
        return ResponseEntity.status(status).body(out);
    }

    private static boolean isClientAbort(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            String name = t.getClass().getSimpleName();
            if (name.equals("ClientAbortException") || name.equals("AsyncRequestNotUsableException")) return true;
            if (t instanceof IOException && t.getMessage() != null
                    && (t.getMessage().contains("Broken pipe") || t.getMessage().contains("Connection reset"))) return true;
        }
        return false;
    }
}
