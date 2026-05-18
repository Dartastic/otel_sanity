// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_sanity/otel_sanity.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_sanity-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('GROQ query records perspective + cdn + cache', () async {
    await tracedSanity<String>(
      operation: 'query',
      projectId: 'p1',
      dataset: 'production',
      apiVersion: '2024-01-01',
      invoke: () async => const SanityCallResult(
        value: 'ok',
        result: SanityResult(
          resultCount: 15,
          perspective: 'previewDrafts',
          useCdn: false,
          fromCache: false,
          queryMs: 27,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('sanity query')!);
    expect(a['sanity.dataset'], 'production');
    expect(a['sanity.perspective'], 'previewDrafts');
    expect(a['sanity.use_cdn'], false);
    expect(a['sanity.result_count'], 15);
    expect(a['sanity.query.duration_ms'], 27);
  });

  test('mutate records mutation_count + transaction.id', () async {
    await tracedSanity<String>(
      operation: 'mutate',
      invoke: () async => const SanityCallResult(
        value: 'ok',
        result: SanityResult(
          mutationCount: 3,
          transactionId: 'tx-1',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('sanity mutate')!);
    expect(a['sanity.mutation_count'], 3);
    expect(a['sanity.transaction.id'], 'tx-1');
  });

  test('suppression skips spans', () async {
    await runWithoutSanityInstrumentationAsync(() async {
      await tracedSanity<String>(
        operation: 'query',
        invoke: () async => const SanityCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('sanity '), isEmpty);
  });
}
