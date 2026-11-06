package ru.mumusic.api.common;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class UriEncodingTest {
    @Test
    void какEncodeURIComponent() {
        assertThat(UriEncoding.encodeComponent("node song (1)!.mp3")).isEqualTo("node%20song%20(1)!.mp3");
        assertThat(UriEncoding.encodeComponent("Мой+трек")).isEqualTo("%D0%9C%D0%BE%D0%B9%2B%D1%82%D1%80%D0%B5%D0%BA");
    }
}
