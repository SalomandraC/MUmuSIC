import 'dart:convert';

import 'package:http/http.dart' as http;

class PocketCommand {
  static const model = 'hf.co/taobao-mnn/MNN-Pocket-0.3B-GGUF:Q4_1';
  static const endpoint = String.fromEnvironment('POCKET_URL',
      defaultValue: 'http://127.0.0.1:11434');

  static Future<String> extractTitle(String transcript) async {
    final response = await http
        .post(Uri.parse('$endpoint/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'stream': false,
              'format': {
                'type': 'object',
                'properties': {
                  'title': {'type': 'string'}
                },
                'required': ['title']
              },
              'options': {'temperature': 0, 'num_predict': 96},
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Extract the requested song title from a play command. Convert spoken numbers to digits. For example: play me track four hundred four -> {"title":"404"}. Return an empty title for unrelated commands.'
                },
                {'role': 'user', 'content': transcript}
              ]
            }))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw StateError('Сервис модели вернул HTTP ${response.statusCode}');
    }
    final message = jsonDecode(utf8.decode(response.bodyBytes))['message'];
    return (jsonDecode(message['content'])['title'] as String).trim();
  }
}
