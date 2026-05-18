import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wicara_mobile/src/core/network/api_client.dart';
import 'package:wicara_mobile/src/features/curriculum/data/api_curriculum_repository.dart';

void main() {
  test('curriculum repository sends locale to knowledge map APIs', () async {
    final requestedUris = <Uri>[];
    final apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:8000',
      httpClient: MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.path == '/api/v1/subjects') {
          return http.Response(
            jsonEncode({
              'items': [
                {'code': 'matematika', 'name': 'Mathematics', 'is_active': true},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/knowledge-map') {
          return http.Response(
            jsonEncode({
              'graph': {
                'title': 'Kurikulum Merdeka Mathematics Knowledge Map',
                'width': 1200,
                'height': 600,
                'top_down': true,
              },
              'groups': [
                {'label': 'Phase D / Numbers', 'x': 28},
              ],
              'nodes': [
                {
                  'id': 'km_d_matematika_bilangan_bulat',
                  'label': 'Integers',
                  'description': 'Understand integers.',
                  'grade_band': 'Phase D',
                  'x': 28,
                  'y': 82,
                  'status': 'ready',
                  'status_label': 'READY',
                },
              ],
              'edges': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'concept': {
              'id': 'km_d_matematika_bilangan_bulat',
              'label': 'Integers',
              'description': 'Understand integers.',
              'grade_band': 'Phase D',
              'x': 28,
              'y': 82,
              'status': 'ready',
              'status_label': 'READY',
            },
            'mastery_confidence': 0.34,
            'prerequisites': [],
            'related_concepts': [],
            'cross_subject_connections': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = ApiCurriculumRepository(apiClient: apiClient);

    await repository.fetchSubjects(locale: 'en');
    await repository.fetchKnowledgeMap(subject: 'matematika', locale: 'en');
    await repository.fetchConceptDetail(
      conceptCode: 'km_d_matematika_bilangan_bulat',
      subject: 'matematika',
      locale: 'en',
    );

    expect(requestedUris[0].queryParameters, {'locale': 'en'});
    expect(requestedUris[1].queryParameters, {
      'subject': 'matematika',
      'locale': 'en',
    });
    expect(requestedUris[2].queryParameters, {
      'subject': 'matematika',
      'locale': 'en',
    });
  });
}
