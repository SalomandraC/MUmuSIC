package ru.mumusic.api.auth;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import ru.mumusic.api.common.HttpError;
import ru.mumusic.api.common.ValidationException;
import ru.mumusic.api.common.ValidationIssues;
import ru.mumusic.api.security.AuthUser;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/auth")
@Tag(name = "Auth", description = "Регистрация, вход, обновление токенов")
public class AuthController {

    private final AuthService auth;
    private final jakarta.validation.Validator validator;

    public AuthController(AuthService auth, jakarta.validation.Validator validator) {
        this.auth = auth;
        this.validator = validator;
    }

    /** User-Agent пишется в refresh_tokens, чтобы потом можно было показать список сессий */
    private static String deviceOf(HttpServletRequest req) {
        String ua = req.getHeader("User-Agent");
        if (ua == null || ua.isEmpty()) return null;
        return ua.length() > 255 ? ua.substring(0, 255) : ua;
    }

    @Operation(summary = "Регистрация")
    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public AuthDtos.AuthResult register(@Valid @RequestBody AuthDtos.RegisterRequest body, HttpServletRequest req) {
        return auth.register(body, deviceOf(req));
    }

    @Operation(summary = "Вход по email и паролю")
    @PostMapping("/login")
    public AuthDtos.AuthResult login(@Valid @RequestBody AuthDtos.LoginRequest body, HttpServletRequest req) {
        return auth.login(body, deviceOf(req));
    }

    @Operation(summary = "Новая пара токенов по refresh-токену (старый отзывается)")
    @PostMapping("/refresh-token")
    public AuthDtos.Tokens refresh(@Valid @RequestBody AuthDtos.RefreshRequest body, HttpServletRequest req) {
        return auth.refresh(body.refreshToken(), deviceOf(req));
    }

    @Operation(summary = "Выход: отзыв refresh-токена или всех сессий (allDevices)")
    @PostMapping("/logout")
    public Map<String, Object> logout(@RequestBody(required = false) AuthDtos.LogoutRequest body) {
        AuthDtos.LogoutRequest input = body == null ? new AuthDtos.LogoutRequest(null, null) : body;
        List<Map<String, Object>> issues = ValidationIssues.validate(validator, input);
        if (!issues.isEmpty()) throw new ValidationException(issues);
        return auth.logout(input.refreshToken(), Boolean.TRUE.equals(input.allDevices()));
    }

    @Operation(summary = "Профиль текущего пользователя", security = @SecurityRequirement(name = "bearerAuth"))
    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal AuthUser user) {
        if (user == null || user.id() == 0) {
            throw HttpError.unauthorized("Необходима аутентификация");
        }
        return Map.of("user", auth.profile(user.id()));
    }
}
