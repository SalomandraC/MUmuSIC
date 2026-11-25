package ru.mumusic.api.common;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.Path;
import jakarta.validation.Validator;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class ValidationIssues {

    private ValidationIssues() {}

    public static <T> List<Map<String, Object>> validate(Validator validator, T value) {
        Set<ConstraintViolation<T>> violations = validator.validate(value);
        return violations.stream()
                .sorted(Comparator.comparing(v -> v.getPropertyPath().toString()))
                .map(v -> issue(pathOf(v.getPropertyPath()), v.getMessage()))
                .toList();
    }

    public static Map<String, Object> issue(List<Object> path, String message) {
        Map<String, Object> issue = new LinkedHashMap<>();
        issue.put("code", "invalid");
        issue.put("path", path);
        issue.put("message", message);
        return issue;
    }

    public static List<Object> pathOf(Path path) {
        List<Object> result = new ArrayList<>();
        for (Path.Node node : path) {
            if (node.getIndex() != null) result.add(node.getIndex());
            if (node.getName() != null) result.add(node.getName());
        }
        return result;
    }

    public static List<Map<String, Object>> prefixed(List<Object> prefix, List<Map<String, Object>> issues) {
        List<Map<String, Object>> out = new ArrayList<>();
        for (Map<String, Object> issue : issues) {
            Map<String, Object> copy = new LinkedHashMap<>(issue);
            List<Object> path = new ArrayList<>(prefix);
            @SuppressWarnings("unchecked")
            List<Object> old = (List<Object>) issue.get("path");
            path.addAll(old);
            copy.put("path", path);
            out.add(copy);
        }
        return out;
    }
}
