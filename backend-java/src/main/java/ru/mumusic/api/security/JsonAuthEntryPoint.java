package ru.mumusic.api.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import ru.mumusic.api.common.JsonConfig;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/** Тексты 401 из authGuard старого сервера, по ним приложение понимает, что пора обновить токен */
public class JsonAuthEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper mapper;

    public JsonAuthEntryPoint(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public void commence(HttpServletRequest req, HttpServletResponse res, AuthenticationException ex) throws IOException {
        Object failure = req.getAttribute(JwtAuthFilter.FAILURE_ATTR);
        Map<String, Object> body = new LinkedHashMap<>();
        if (failure instanceof JwtAuthFilter.Missing) {
            body.put("error", "Необходим заголовок Authorization");
        } else if (failure instanceof JwtAuthFilter.NoToken) {
            body.put("error", "Не найден токен доступа");
        } else if (failure instanceof JwtAuthFilter.Expired expired) {
            body.put("error", "Токен истек");
            body.put("code", "TOKEN_EXPIRED");
            body.put("message", "Используйте refresh token для получения нового access token");
            body.put("expiredAt", expired.expiredAt() == null ? null : JsonConfig.iso(expired.expiredAt()));
        } else {
            body.put("error", "Недействительный или истекший токен");
        }
        res.setStatus(401);
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        mapper.writeValue(res.getOutputStream(), body);
    }
}
