package ru.mumusic.api.common;

import java.time.Duration;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class TimeSpan {

    private static final Pattern FORMAT = Pattern.compile(
            "^(-?(?:\\d+)?\\.?\\d+) *(milliseconds?|msecs?|ms|seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h|days?|d|weeks?|w|years?|yrs?|y)?$",
            Pattern.CASE_INSENSITIVE);

    private static final double SECOND = 1000;
    private static final double MINUTE = SECOND * 60;
    private static final double HOUR = MINUTE * 60;
    private static final double DAY = HOUR * 24;
    private static final double WEEK = DAY * 7;
    private static final double YEAR = DAY * 365.25;

    private TimeSpan() {}

    public static Duration parse(String value) {
        if (value == null || value.isEmpty() || value.length() > 100) {
            throw new IllegalArgumentException("неверный срок: " + value);
        }
        Matcher m = FORMAT.matcher(value.trim());
        if (!m.matches()) {
            throw new IllegalArgumentException("неверный срок: " + value + " (пример: 60m, 7d)");
        }
        double n = Double.parseDouble(m.group(1));
        String unit = m.group(2) == null ? "ms" : m.group(2).toLowerCase(Locale.ROOT);
        double factor = switch (unit) {
            case "years", "year", "yrs", "yr", "y" -> YEAR;
            case "weeks", "week", "w" -> WEEK;
            case "days", "day", "d" -> DAY;
            case "hours", "hour", "hrs", "hr", "h" -> HOUR;
            case "minutes", "minute", "mins", "min", "m" -> MINUTE;
            case "seconds", "second", "secs", "sec", "s" -> SECOND;
            default -> 1;
        };
        long millis = (long) (n * factor);
        if (millis <= 0) {
            throw new IllegalArgumentException("срок должен быть положительным: " + value);
        }
        return Duration.ofMillis(millis);
    }
}
