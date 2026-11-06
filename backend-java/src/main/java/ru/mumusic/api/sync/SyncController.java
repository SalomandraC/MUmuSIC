package ru.mumusic.api.sync;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Validator;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.mumusic.api.common.HttpError;
import ru.mumusic.api.common.ValidationException;
import ru.mumusic.api.common.ValidationIssues;
import ru.mumusic.api.security.AuthUser;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Синхронизация плейлистов приложения с сервером */
@RestController
@RequestMapping("/sync")
@Tag(name = "Sync", description = "Синхронизация плейлистов")
public class SyncController {

    private final SyncRepository repository;
    private final ObjectMapper mapper;
    private final Validator validator;

    public SyncController(SyncRepository repository, ObjectMapper mapper, Validator validator) {
        this.repository = repository;
        this.mapper = mapper;
        this.validator = validator;
    }

    @Operation(summary = "Плейлисты пользователя", security = @SecurityRequirement(name = "bearerAuth"))
    @GetMapping("/data")
    public Map<String, Object> data(@AuthenticationPrincipal AuthUser user) {
        return Map.of("playlists", repository.getPlaylists(requireUser(user)));
    }

    @Operation(summary = "Сохранить данные {playlists: [...]}", security = @SecurityRequirement(name = "bearerAuth"))
    @PostMapping("/upload")
    public Map<String, Object> upload(@AuthenticationPrincipal AuthUser user,
                                      @RequestBody(required = false) JsonNode body) {
        long userId = requireUser(user);
        SyncDtos.SyncData data;
        try {
            data = mapper.treeToValue(body == null ? mapper.createObjectNode() : body, SyncDtos.SyncData.class);
        } catch (Exception e) {
            throw new ValidationException(List.of(ValidationIssues.issue(List.of(), "Неверный формат данных")));
        }
        if (data == null) {
            throw new ValidationException(List.of(ValidationIssues.issue(List.of(), "Ожидался объект")));
        }
        List<Map<String, Object>> issues = ValidationIssues.validate(validator, data);
        if (!issues.isEmpty()) throw new ValidationException(issues);

        repository.savePlaylists(userId, data.playlists());
        return ok("Данные успешно сохранены");
    }

    @Operation(summary = "Сохранить массив плейлистов", security = @SecurityRequirement(name = "bearerAuth"))
    @PostMapping("/playlists")
    public Map<String, Object> playlists(@AuthenticationPrincipal AuthUser user,
                                         @RequestBody(required = false) JsonNode body) {
        long userId = requireUser(user);
        if (body == null || !body.isArray()) {
            throw playlistsInvalid(List.of(ValidationIssues.issue(List.of(), "Ожидался массив плейлистов")));
        }

        List<SyncDtos.Playlist> playlists = new ArrayList<>();
        List<Map<String, Object>> issues = new ArrayList<>();
        for (int i = 0; i < body.size(); i++) {
            try {
                SyncDtos.Playlist playlist = mapper.treeToValue(body.get(i), SyncDtos.Playlist.class);
                if (playlist == null) {
                    issues.add(ValidationIssues.issue(List.of(i), "Ожидался объект"));
                    continue;
                }
                issues.addAll(ValidationIssues.prefixed(List.of(i), ValidationIssues.validate(validator, playlist)));
                playlists.add(playlist);
            } catch (Exception e) {
                issues.add(ValidationIssues.issue(List.of(i), "Неверный формат плейлиста"));
            }
        }
        if (!issues.isEmpty()) throw playlistsInvalid(issues);

        repository.savePlaylists(userId, playlists);
        return ok("Плейлисты успешно сохранены");
    }

    private static Map<String, Object> ok(String message) {
        Map<String, Object> out = new java.util.LinkedHashMap<>();
        out.put("success", true);
        out.put("message", message);
        return out;
    }

    private static HttpError playlistsInvalid(List<Map<String, Object>> issues) {
        return new HttpError(400, "Ошибка валидации плейлистов", Map.of("details", issues));
    }

    private static long requireUser(AuthUser user) {
        if (user == null || user.id() == 0) throw HttpError.unauthorized("Необходима аутентификация");
        return user.id();
    }
}
