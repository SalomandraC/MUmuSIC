package ru.mumusic.api.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

/**
 * Разбирает заголовок Authorization так же, как authGuard: "<схема> <токен>".
 * Если токена нет или он плохой, запоминает причину; ответ 401 с нужным текстом
 * формирует {@link JsonAuthEntryPoint}, и только для защищённых маршрутов.
 */
public class JwtAuthFilter extends OncePerRequestFilter {

    public static final String FAILURE_ATTR = JwtAuthFilter.class.getName() + ".failure";

    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);

    private final TokenService tokens;

    public JwtAuthFilter(TokenService tokens) {
        this.tokens = tokens;
    }

    public sealed interface Failure permits Missing, NoToken, Invalid, Expired {}
    public record Missing() implements Failure {}
    public record NoToken() implements Failure {}
    public record Invalid() implements Failure {}
    public record Expired(java.time.Instant expiredAt) implements Failure {}

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header == null || header.isEmpty()) {
            req.setAttribute(FAILURE_ATTR, new Missing());
        } else {
            String[] parts = header.split(" ", -1);
            String token = parts.length > 1 ? parts[1] : "";
            if (token.isEmpty()) {
                req.setAttribute(FAILURE_ATTR, new NoToken());
            } else {
                try {
                    TokenService.TokenPayload payload = tokens.verifyAccessToken(token);
                    AuthUser user = new AuthUser(payload.sub(), payload.role());
                    var auth = new UsernamePasswordAuthenticationToken(user, null,
                            List.of(new SimpleGrantedAuthority("ROLE_" + String.valueOf(payload.role()).toUpperCase())));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                } catch (TokenService.TokenExpiredException e) {
                    log.debug("Access-токен истёк: {}", e.expiredAt());
                    req.setAttribute(FAILURE_ATTR, new Expired(e.expiredAt()));
                } catch (TokenService.InvalidTokenException e) {
                    log.debug("Access-токен не прошёл проверку: {}", e.getMessage());
                    req.setAttribute(FAILURE_ATTR, new Invalid());
                }
            }
        }
        chain.doFilter(req, res);
    }
}
