package ru.mumusic.api.common;

/** Поведение строковых функций JS, от которого зависят ответы сервера */
public final class JsStrings {

    private JsStrings() {}

    /** Пробельные символы String.prototype.trim() */
    public static boolean isJsWhitespace(char c) {
        return c == ' ' || c == '\t' || c == '\n' || c == '\u000B' || c == '\f' || c == '\r'
                || c == ' ' || c == ' ' || (c >= ' ' && c <= ' ')
                || c == ' ' || c == ' ' || c == ' ' || c == ' '
                || c == '　' || c == '﻿';
    }

    public static String trim(String s) {
        int start = 0;
        int end = s.length();
        while (start < end && isJsWhitespace(s.charAt(start))) start++;
        while (end > start && isJsWhitespace(s.charAt(end - 1))) end--;
        return s.substring(start, end);
    }
}
