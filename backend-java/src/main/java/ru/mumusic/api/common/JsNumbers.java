package ru.mumusic.api.common;

/** Number(value) из JS для параметров пути и полей формы */
public final class JsNumbers {

    private JsNumbers() {}

    /** NaN, если строка не число; пустая строка — 0, как в JS */
    public static double toNumber(String value) {
        if (value == null) return Double.NaN;
        String s = JsStrings.trim(value);
        if (s.isEmpty()) return 0;
        if (s.equals("Infinity") || s.equals("+Infinity")) return Double.POSITIVE_INFINITY;
        if (s.equals("-Infinity")) return Double.NEGATIVE_INFINITY;
        if (!s.matches("[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?")) return Double.NaN;
        return Double.parseDouble(s);
    }

    /** Положительное целое из строки или null */
    public static Long positiveInt(String value) {
        double n = toNumber(value);
        if (Double.isNaN(n) || Double.isInfinite(n) || n != Math.rint(n) || n <= 0 || n > Long.MAX_VALUE) return null;
        return (long) n;
    }
}
