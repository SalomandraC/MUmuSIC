package ru.mumusic.api.storage;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static ru.mumusic.api.storage.RangeStreaming.Mode.GUEST;
import static ru.mumusic.api.storage.RangeStreaming.Mode.TOP_CHART;

class RangeStreamingTest {

    @Test
    void обычныеДиапазоны() {
        assertThat(RangeStreaming.parse("bytes=0-", 1000, GUEST)).containsExactly(0, 999);
        assertThat(RangeStreaming.parse("bytes=100-199", 1000, GUEST)).containsExactly(100, 199);
        assertThat(RangeStreaming.parse("bytes=-100", 1000, GUEST)).containsExactly(900, 999);
    }

    @Test
    void заПределамиФайла416ДляГостевых() {
        assertThat(RangeStreaming.parse("bytes=1000-", 1000, GUEST)).isNull();
        assertThat(RangeStreaming.parse("bytes=0-1000", 1000, GUEST)).isNull();
        assertThat(RangeStreaming.parse("bytes=500-100", 1000, GUEST)).isNull();
    }

    @Test
    void топЧартОбрезаетКонецПоФайлу() {
        assertThat(RangeStreaming.parse("bytes=0-5000", 1000, TOP_CHART)).containsExactly(0, 999);
    }
}
