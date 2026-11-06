package ru.mumusic.api.storage;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

/**
 * Отдача аудиофайла с поддержкой Range, по правилам handleRangeRequest из guest.routes.ts:
 * без Range — 200 и весь файл; "bytes=start-end" — 206; диапазон за пределами файла — 416.
 * Дополнительно поддержан суффиксный диапазон "bytes=-N" (старый сервер на нём падал с 500).
 */
public final class RangeStreaming {

    private static final int BUFFER = 64 * 1024;

    private RangeStreaming() {}

    public enum Mode {
        /** /guest-tracks: Accept-Ranges всегда, строгая проверка диапазона (416) */
        GUEST,
        /** /top-charts/:id/stream: без Accept-Ranges в полном ответе, конец диапазона обрезается по файлу */
        TOP_CHART
    }

    public static void stream(HttpServletRequest req, HttpServletResponse res, Path file, String contentType, Mode mode)
            throws IOException {
        long size = Files.size(file);
        String range = req.getHeader("Range");

        if (range == null || range.isEmpty()) {
            res.setStatus(200);
            res.setContentType(contentType);
            res.setContentLengthLong(size);
            if (mode == Mode.GUEST) res.setHeader("Accept-Ranges", "bytes");
            copy(req, res, file, 0, size);
            return;
        }

        long[] bounds = parse(range, size, mode);
        if (bounds == null) {
            res.setStatus(416);
            res.setHeader("Content-Range", "bytes */" + size);
            res.setContentLength(0);
            return;
        }
        long start = bounds[0];
        long end = bounds[1];
        long length = end - start + 1;

        res.setStatus(206);
        res.setHeader("Content-Range", "bytes " + start + "-" + end + "/" + size);
        res.setHeader("Accept-Ranges", "bytes");
        res.setContentLengthLong(length);
        res.setContentType(contentType);
        copy(req, res, file, start, length);
    }

    /** null — диапазон не удовлетворим (416) */
    static long[] parse(String header, long size, Mode mode) {
        String spec = header.replaceFirst("bytes=", "");
        int comma = spec.indexOf(',');
        if (comma >= 0) spec = spec.substring(0, comma); // несколько диапазонов: берём первый, как parseInt в Node
        int dash = spec.indexOf('-');
        String startPart = dash >= 0 ? spec.substring(0, dash).trim() : spec.trim();
        String endPart = dash >= 0 ? spec.substring(dash + 1).trim() : "";

        Long startValue = leadingNumber(startPart);
        Long endValue = leadingNumber(endPart);

        long start;
        long end;
        if (startValue == null) {
            // bytes=-N: последние N байт
            if (endValue == null || endValue == 0) return null;
            start = Math.max(0, size - endValue);
            end = size - 1;
        } else {
            start = startValue;
            end = endValue != null ? endValue : size - 1;
            if (mode == Mode.TOP_CHART && end >= size) end = size - 1;
        }

        if (start >= size || end >= size || start > end) return null;
        return new long[]{start, end};
    }

    /** parseInt(value, 10): цифры в начале строки, иначе null (NaN) */
    private static Long leadingNumber(String value) {
        int i = 0;
        while (i < value.length() && Character.isDigit(value.charAt(i))) i++;
        if (i == 0) return null;
        try {
            return Long.parseLong(value.substring(0, i));
        } catch (NumberFormatException e) {
            return Long.MAX_VALUE;
        }
    }

    private static void copy(HttpServletRequest req, HttpServletResponse res, Path file, long start, long length)
            throws IOException {
        if ("HEAD".equalsIgnoreCase(req.getMethod())) return;
        try (FileChannel channel = FileChannel.open(file, StandardOpenOption.READ)) {
            channel.position(start);
            InputStream in = Channels.newInputStream(channel);
            OutputStream out = res.getOutputStream();
            byte[] buffer = new byte[BUFFER];
            long remaining = length;
            while (remaining > 0) {
                int read = in.read(buffer, 0, (int) Math.min(buffer.length, remaining));
                if (read < 0) break;
                out.write(buffer, 0, read);
                remaining -= read;
            }
            out.flush();
        }
    }
}
