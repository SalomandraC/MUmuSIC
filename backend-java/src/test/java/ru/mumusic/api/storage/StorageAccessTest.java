package ru.mumusic.api.storage;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static ru.mumusic.api.storage.StorageAccess.Access.DENY;
import static ru.mumusic.api.storage.StorageAccess.Access.PRIVATE;
import static ru.mumusic.api.storage.StorageAccess.Access.PUBLIC;

/** Те же случаи, что в storageGuard.test.ts старого сервера */
class StorageAccessTest {

    @Nested
    class NormalizePath {
        @Test
        void декодируетПутьИУбираетВедущийСлэш() {
            assertThat(StorageAccess.normalizePath("/users/3/Best%20Mann%20-%20Mst.m4a")).isEqualTo("users/3/Best Mann - Mst.m4a");
        }

        @Test
        void неВыпускаетЗаПределыХранилища() {
            assertThat(StorageAccess.normalizePath("/../server/a.mp3")).isEqualTo("server/a.mp3");
            assertThat(StorageAccess.normalizePath("/users/3/../../../etc/passwd")).isEqualTo("etc/passwd");
            assertThat(StorageAccess.normalizePath("/%2e%2e/%2e%2e/etc/passwd")).isEqualTo("etc/passwd");
        }

        @Test
        void отклоняетСкрытыеФайлыИПапки() {
            assertThat(StorageAccess.normalizePath("/.tmp/abc")).isNull();
            assertThat(StorageAccess.normalizePath("/users/3/.hidden.mp3")).isNull();
        }

        @Test
        void отклоняетОбратныеСлэшиNulИБитуюКодировку() {
            assertThat(StorageAccess.normalizePath("/users\\3\\a.mp3")).isNull();
            assertThat(StorageAccess.normalizePath("/a%00.mp3")).isNull();
            assertThat(StorageAccess.normalizePath("/%E0%A4%A")).isNull();
        }

        @Test
        void пустойПутьНекорректен() {
            assertThat(StorageAccess.normalizePath("/")).isNull();
        }

        @Test
        void кириллицаИПлюс() {
            assertThat(StorageAccess.normalizePath("/guest/%D0%9C%D0%BE%D0%B9+%D1%82%D1%80%D0%B5%D0%BA.mp3")).isEqualTo("guest/Мой+трек.mp3");
        }
    }

    @Nested
    class Resolve {
        private final StorageAccess.Credentials none = StorageAccess.Credentials.none();

        @Test
        void общиеТрекиИNfcДоступныВсем() {
            assertThat(StorageAccess.resolve("404Heart.mp3", none)).isEqualTo(PUBLIC);
            assertThat(StorageAccess.resolve("nfc/Dreams.mp3", none)).isEqualTo(PUBLIC);
        }

        @Test
        void личныйФайлБезУчётныхДанныхЗакрыт() {
            assertThat(StorageAccess.resolve("users/3/a.mp3", none)).isEqualTo(DENY);
        }

        @Test
        void владелецСAccessТокеномПолучаетДоступ() {
            assertThat(StorageAccess.resolve("users/3/a.mp3", new StorageAccess.Credentials(3L, null, null))).isEqualTo(PRIVATE);
        }

        @Test
        void чужойAccessТокенНеДаётДоступа() {
            assertThat(StorageAccess.resolve("users/3/a.mp3", new StorageAccess.Credentials(4L, null, null))).isEqualTo(DENY);
        }

        @Test
        void подписаннаяСсылкаРаботаетТолькоДляСвоегоФайла() {
            var media = new StorageAccess.Credentials(null, 3L, "users/3/a.mp3");
            assertThat(StorageAccess.resolve("users/3/a.mp3", media)).isEqualTo(PRIVATE);
            assertThat(StorageAccess.resolve("users/3/b.mp3", media)).isEqualTo(DENY);
            assertThat(StorageAccess.resolve("users/4/a.mp3", new StorageAccess.Credentials(null, 3L, "users/4/a.mp3"))).isEqualTo(DENY);
        }

        @Test
        void некорректныйIdВладельцаИСамаПапкаЗакрыты() {
            var owner = new StorageAccess.Credentials(3L, null, null);
            assertThat(StorageAccess.resolve("users/abc/a.mp3", owner)).isEqualTo(DENY);
            assertThat(StorageAccess.resolve("users/3", owner)).isEqualTo(DENY);
        }
    }
}
