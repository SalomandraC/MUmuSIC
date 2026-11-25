/// Prefer an exact title. A partial title must identify just one recording.
int matchTrackTitle(String query, List<String> titles) {
  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'four (?:hundred|houndred)(?: and)? four'), '404')
      .replaceAllMapped(RegExp(r'([0-9])([a-zа-яё])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
  final key = normalize(query);
  if (key.isEmpty) return -1;
  final names = titles.map(normalize).toList();
  final exact = names.indexOf(key);
  if (exact >= 0) return names.lastIndexOf(key) == exact ? exact : -1;
  final matches = [
    for (var i = 0; i < names.length; i++)
      if (' ${names[i]} '.contains(' $key ')) i
  ];
  return matches.length == 1 ? matches.first : -1;
}
