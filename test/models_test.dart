import 'package:flutter_test/flutter_test.dart';
import 'package:asobaby/models/models.dart';

void main() {
  group('GameConfig', () {
    test('fromJson parses valid config', () {
      final json = {
        'id': 'bubble_pop_animals',
        'type': 'bubblePop',
        'title': 'Bubble Pop Animals',
        'description': 'Pop bubbles with animal faces!',
        'thumbnailPath': 'thumbnail.png',
        'assets': {
          'bg': 'background.png',
          'pop_sound': 'pop.mp3',
        },
        'settings': {
          'bubbleCount': 10,
          'speed': 1.5,
        },
        'version': 2,
      };

      final config = GameConfig.fromJson(json);

      expect(config.id, 'bubble_pop_animals');
      expect(config.type, GameType.bubblePop);
      expect(config.title, 'Bubble Pop Animals');
      expect(config.description, 'Pop bubbles with animal faces!');
      expect(config.thumbnailPath, 'thumbnail.png');
      expect(config.assets['bg'], 'background.png');
      expect(config.assets['pop_sound'], 'pop.mp3');
      expect(config.settings['bubbleCount'], 10);
      expect(config.settings['speed'], 1.5);
      expect(config.version, 2);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test_game',
        'type': 'tapResponse',
        'title': 'Test',
        'thumbnailPath': 'thumb.png',
        'assets': <String, String>{},
      };

      final config = GameConfig.fromJson(json);

      expect(config.description, '');
      expect(config.settings, isEmpty);
      expect(config.version, 1);
    });

    test('toJson roundtrip preserves data', () {
      final original = GameConfig(
        id: 'test',
        type: GameType.drawing,
        title: 'Drawing Fun',
        description: 'Draw stuff',
        thumbnailPath: 'thumb.png',
        assets: {'brush': 'brush.png'},
        settings: {'colors': 5},
        version: 3,
      );

      final json = original.toJson();
      final restored = GameConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.version, original.version);
      expect(restored.assets, original.assets);
    });

    test('fromJson throws on invalid game type', () {
      final json = {
        'id': 'bad',
        'type': 'nonexistent',
        'title': 'Bad Game',
        'thumbnailPath': 'x.png',
        'assets': {},
      };

      expect(() => GameConfig.fromJson(json), throwsStateError);
    });
  });

  group('GameManifest', () {
    test('fromJson parses manifest with games', () {
      final json = {
        'manifestVersion': 1,
        'baseUrl': 'https://example.blob.core.windows.net/games',
        'games': [
          {
            'id': 'bubble_pop_animals',
            'version': 2,
            'title': 'Bubble Pop Animals',
            'sizeBytes': 524288,
          },
          {
            'id': 'peekaboo_farm',
            'version': 1,
            'title': 'Peekaboo Farm',
            'sizeBytes': 1048576,
          },
        ],
      };

      final manifest = GameManifest.fromJson(json);

      expect(manifest.manifestVersion, 1);
      expect(manifest.baseUrl, 'https://example.blob.core.windows.net/games');
      expect(manifest.games, hasLength(2));
      expect(manifest.games[0].id, 'bubble_pop_animals');
      expect(manifest.games[0].version, 2);
      expect(manifest.games[0].sizeBytes, 524288);
      expect(manifest.games[1].id, 'peekaboo_farm');
    });

    test('toJson roundtrip preserves manifest', () {
      final original = GameManifest(
        manifestVersion: 1,
        baseUrl: 'https://example.com',
        games: [
          GameSummary(
              id: 'test', version: 1, title: 'Test', sizeBytes: 100),
        ],
      );

      final json = original.toJson();
      final restored = GameManifest.fromJson(json);

      expect(restored.manifestVersion, original.manifestVersion);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.games, hasLength(1));
      expect(restored.games[0].id, 'test');
    });
  });
}
