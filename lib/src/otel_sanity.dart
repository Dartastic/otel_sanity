// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_sanity_suppression.dart';

const _tracerName = 'dartastic_otel_libs_sanity';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class SanityResult {
  const SanityResult({
    this.resultCount,
    this.mutationCount,
    this.perspective,
    this.useCdn,
    this.fromCache,
    this.queryMs,
    this.transactionId,
    this.requestId,
    this.statusCode,
  });

  /// Number of docs in `result` for GROQ queries.
  final int? resultCount;

  /// Mutations applied (`create`, `patch`, `delete`, `createIfNotExists`).
  final int? mutationCount;

  /// `published` / `previewDrafts` / `raw` — drives which docs are
  /// included and is a separate cost dim from dataset.
  final String? perspective;

  /// `useCdn` toggle — Sanity CDN endpoints are free read, API
  /// endpoints are billed per query.
  final bool? useCdn;

  /// Whether the CDN served this from cache.
  final bool? fromCache;

  /// Query execution time from `X-Sanity-Run-Time` (ms).
  final int? queryMs;

  /// `transactionId` from a mutate response.
  final String? transactionId;

  /// `X-Request-Id`.
  final String? requestId;
  final int? statusCode;
}

class SanityCallResult<T> {
  const SanityCallResult({required this.value, this.result});
  final T value;
  final SanityResult? result;
}

/// Wraps a Sanity API call in a CLIENT span. [operation] is one of
/// `query`, `mutate`, `getDocument`, `getDocuments`, `listen`,
/// `assets.upload`, `assets.url`, `history`, `users`.
Future<T> tracedSanity<T>({
  required String operation,
  required Future<SanityCallResult<T>> Function() invoke,
  String? projectId,
  String? dataset,
  String? apiVersion,
}) async {
  if (sanityInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'sanity',
    'rpc.method': operation,
    'sanity.operation': operation,
  };
  if (projectId != null) m['sanity.project.id'] = projectId;
  if (dataset != null) m['sanity.dataset'] = dataset;
  if (apiVersion != null) m['sanity.api_version'] = apiVersion;

  final kind = operation == 'listen' ? SpanKind.consumer : SpanKind.client;
  final span = _tracer().startSpan(
    'sanity $operation',
    kind: kind,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.resultCount != null) {
        extras.add(OTel.attributeInt(
          'sanity.result_count',
          r.result!.resultCount!,
        ));
      }
      if (r.result!.mutationCount != null) {
        extras.add(OTel.attributeInt(
          'sanity.mutation_count',
          r.result!.mutationCount!,
        ));
      }
      if (r.result!.perspective != null) {
        extras.add(OTel.attributeString(
          'sanity.perspective',
          r.result!.perspective!,
        ));
      }
      if (r.result!.useCdn != null) {
        extras.add(OTel.attributeBool(
          'sanity.use_cdn',
          r.result!.useCdn!,
        ));
      }
      if (r.result!.fromCache != null) {
        extras.add(OTel.attributeBool(
          'sanity.cache.hit',
          r.result!.fromCache!,
        ));
      }
      if (r.result!.queryMs != null) {
        extras.add(OTel.attributeInt(
          'sanity.query.duration_ms',
          r.result!.queryMs!,
        ));
      }
      if (r.result!.transactionId != null) {
        extras.add(OTel.attributeString(
          'sanity.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'sanity.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Sanity HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
