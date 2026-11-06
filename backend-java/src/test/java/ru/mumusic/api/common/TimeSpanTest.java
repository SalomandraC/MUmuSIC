package ru.mumusic.api.common;

import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TimeSpanTest {

    @Test
    void форматБиблиотекиMs() {
        assertThat(TimeSpan.parse("60m")).isEqualTo(Duration.ofMinutes(60));
        assertThat(TimeSpan.parse("7d")).isEqualTo(Duration.ofDays(7));
        assertThat(TimeSpan.parse("1h")).isEqualTo(Duration.ofHours(1));
        assertThat(TimeSpan.parse("2 days")).isEqualTo(Duration.ofDays(2));
        assertThat(TimeSpan.parse("1500")).isEqualTo(Duration.ofMillis(1500));
    }

    @Test
    void мусорОтклоняется() {
        assertThatThrownBy(() -> TimeSpan.parse("abc")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> TimeSpan.parse("")).isInstanceOf(IllegalArgumentException.class);
    }
}
