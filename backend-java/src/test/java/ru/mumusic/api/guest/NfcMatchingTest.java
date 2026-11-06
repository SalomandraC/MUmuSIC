package ru.mumusic.api.guest;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class NfcMatchingTest {

    private final List<String> files = List.of("Dreams.mp3", "Veter.m4a", "enSky.mp3");

    @Test
    void чиститНазваниеСМетки() {
        assertThat(GuestTracksController.cleanNfcTitle("\u0002enVeter ")).isEqualTo("Veter");
        assertThat(GuestTracksController.cleanNfcTitle("  Dreams ")).isEqualTo("Dreams");
    }

    @Test
    void находитФайлПоТемЖеПравилам() {
        assertThat(GuestTracksController.findNfcFile(files, "dreams")).isEqualTo("Dreams.mp3");
        assertThat(GuestTracksController.findNfcFile(files, "Dreams.mp3")).isEqualTo("Dreams.mp3");
        assertThat(GuestTracksController.findNfcFile(files, "dream")).isEqualTo("Dreams.mp3");
        assertThat(GuestTracksController.findNfcFile(files, "dreamsss")).isEqualTo("Dreams.mp3");
        assertThat(GuestTracksController.findNfcFile(files, "sky")).isEqualTo("enSky.mp3");
        assertThat(GuestTracksController.findNfcFile(files, "zzz")).isNull();
    }
}
