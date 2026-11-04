// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_sanity/otel_sanity.dart';

/// Traces Sanity calls with OpenTelemetry.
///
/// `otel_sanity` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Sanity call in
/// [tracedSanity]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'sanity-example');

  // Wraps a Sanity API call in a CLIENT span.
  final sanityId = await tracedSanity<String>(
    operation: 'assets.upload',
    projectId: 'project_8f3a2c',
    dataset: 'example',
    apiVersion: '1',
    invoke: () async {
      // Make the Sanity call here, then report what it returned.
      const id = 'sanity_8f3a2c';
      return const SanityCallResult(
          value: id,
          result: SanityResult(
              resultCount: 3,
              mutationCount: 3,
              perspective: 'published',
              useCdn: true,
              fromCache: true,
              queryMs: 120,
              transactionId: 'transaction_8f3a2c',
              requestId: 'request_8f3a2c',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedSanity assets.upload returned $sanityId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSanityInstrumentationAsync.
  await runWithoutSanityInstrumentationAsync(
    () => tracedSanity<String>(
      operation: 'assets.upload',
      projectId: 'project_8f3a2c',
      dataset: 'example',
      apiVersion: '1',
      invoke: () async {
        const id = 'sanity_8f3a2c';
        return const SanityCallResult(
            value: id,
            result: SanityResult(
                resultCount: 3,
                mutationCount: 3,
                perspective: 'published',
                useCdn: true,
                fromCache: true,
                queryMs: 120,
                transactionId: 'transaction_8f3a2c',
                requestId: 'request_8f3a2c',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
