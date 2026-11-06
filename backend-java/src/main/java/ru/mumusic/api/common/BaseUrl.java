package ru.mumusic.api.common;

import jakarta.servlet.http.HttpServletRequest;

/** protocol://host запроса, как `${req.protocol}://${req.get('host')}` в Express с trust proxy */
public final class BaseUrl {

    private BaseUrl() {}

    public static String protocol(HttpServletRequest req) {
        String forwarded = req.getHeader("X-Forwarded-Proto");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return req.getScheme();
    }

    public static String host(HttpServletRequest req) {
        return req.getHeader("Host");
    }

    public static String of(HttpServletRequest req) {
        return protocol(req) + "://" + host(req);
    }
}
