package ru.mumusic.api.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.firewall.RequestRejectedHandler;
import org.springframework.security.web.firewall.StrictHttpFirewall;
import org.springframework.security.web.firewall.HttpFirewall;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import ru.mumusic.api.common.GlobalExceptionHandler;
import ru.mumusic.api.security.JsonAuthEntryPoint;
import ru.mumusic.api.security.JwtAuthFilter;
import ru.mumusic.api.security.TokenService;

import java.util.ArrayList;
import java.util.List;

/**
 * Stateless-безопасность на JWT. Защищены те же маршруты, где в Express стоял authGuard:
 * /auth/me, /tracks/**, /sync/**. /storage/** проверяет доступ сам (StorageController).
 */
@Configuration
public class SecurityConfig {

    private final CorsConfigurationSource corsConfigurationSource;

    public SecurityConfig(AppConfig config) {
        this.corsConfigurationSource = buildCors(config);
    }

    private static final List<String> BASE_ORIGINS = List.of(
            "http://localhost:3000",
            "http://localhost:5050",
            "https://f4x1pn2ft.localto.net",
            "http://d91098wj.beget.tech"
    );

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, TokenService tokens, ObjectMapper mapper)
            throws Exception {
        JsonAuthEntryPoint entryPoint = new JsonAuthEntryPoint(mapper);
        http
                .csrf(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .requestCache(AbstractHttpConfigurer::disable)
                .anonymous(a -> {})
                .cors(c -> c.configurationSource(corsConfigurationSource))
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                // Кэширование задают сами контроллеры (например, /storage)
                .headers(h -> h.cacheControl(cc -> cc.disable()))
                .exceptionHandling(e -> e.authenticationEntryPoint(entryPoint))
                .addFilterBefore(new JwtAuthFilter(tokens), UsernamePasswordAuthenticationFilter.class)
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/auth/me").authenticated()
                        .requestMatchers("/tracks", "/tracks/**").authenticated()
                        .requestMatchers("/sync/**").authenticated()
                        .anyRequest().permitAll());
        return http.build();
    }

    private static CorsConfigurationSource buildCors(AppConfig config) {
        CorsConfiguration cors = new CorsConfiguration();
        if (config.isDevelopment()) {
            // В development разрешён любой источник
            cors.setAllowedOriginPatterns(List.of("*"));
        } else {
            List<String> origins = new ArrayList<>(BASE_ORIGINS);
            origins.addAll(config.corsOrigins());
            cors.setAllowedOrigins(origins);
        }
        cors.setAllowedMethods(List.of("GET", "POST", "PATCH", "DELETE", "OPTIONS"));
        cors.setAllowedHeaders(List.of("Content-Type", "Authorization", "localtonet-skip-warning", "Range",
                "Accept-Ranges", "Content-Range", "Accept", "X-Request-Id"));
        cors.setExposedHeaders(List.of("Content-Range", "Accept-Ranges", "Content-Length", "Content-Type", "X-Request-Id"));
        cors.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cors);
        return source;
    }

    /** Разрешаем %25 в пути: в названиях общих треков встречается знак процента */
    @Bean
    public HttpFirewall httpFirewall() {
        StrictHttpFirewall firewall = new StrictHttpFirewall();
        firewall.setAllowUrlEncodedPercent(true);
        return firewall;
    }

    /** Подозрительные пути (../, %2F, NUL) отклоняются как несуществующие, тем же JSON, что и 404 */
    @Bean
    public RequestRejectedHandler requestRejectedHandler(ObjectMapper mapper) {
        return (req, res, ex) -> {
            res.setStatus(HttpStatus.NOT_FOUND.value());
            res.setCharacterEncoding("UTF-8");
            res.setContentType("application/json");
            mapper.writeValue(res.getOutputStream(), GlobalExceptionHandler.notFoundBody(req));
        };
    }
}
