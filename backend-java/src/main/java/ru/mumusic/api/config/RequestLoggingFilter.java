package ru.mumusic.api.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * X-Request-Id и журнал запросов (замена pino-http).
 * id берётся от nginx, если он есть, иначе создаётся; тот же id возвращается клиенту.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestLoggingFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger("http");
    private static final Pattern VALID_ID = Pattern.compile("^[\\w-]{1,128}$");
    private static final Pattern TOKEN_PARAM = Pattern.compile("([?&]token=)[^&]+");

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String incoming = req.getHeader("X-Request-Id");
        String id = incoming != null && VALID_ID.matcher(incoming).matches() ? incoming : UUID.randomUUID().toString();
        res.setHeader("X-Request-Id", id);
        MDC.put("requestId", id);
        long started = System.nanoTime();
        try {
            chain.doFilter(req, res);
        } finally {
            String uri = req.getRequestURI();
            // Проверки балансировщика каждые несколько секунд только засоряют лог
            if (!uri.equals("/health") && !uri.equals("/ready")) {
                String url = stripToken(req.getQueryString() == null ? uri : uri + "?" + req.getQueryString());
                long ms = (System.nanoTime() - started) / 1_000_000;
                int status = res.getStatus();
                if (status >= 500) {
                    log.error("{} {} {} {}ms", req.getMethod(), url, status, ms);
                } else if (status >= 400) {
                    log.warn("{} {} {} {}ms", req.getMethod(), url, status, ms);
                } else {
                    log.info("{} {} {} {}ms", req.getMethod(), url, status, ms);
                }
            }
            MDC.remove("requestId");
        }
    }

    /** Подписанный ?token= не должен попадать в логи */
    static String stripToken(String url) {
        return TOKEN_PARAM.matcher(url).replaceFirst("$1[скрыто]");
    }
}
