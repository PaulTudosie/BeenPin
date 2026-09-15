import 'dart:io';
import 'dart:ui' as ui;

import 'package:been/features/journey/journey_photo.dart';
import 'package:been/models/journey_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Frames extends ImageStreamCompleter {
  void show(ui.Image image) => setImage(ImageInfo(image: image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'local stays mounted through URL and decode, remote renewal retains frame',
      (tester) async {
    const localPath = '/test/local.jpg';
    const url = 'https://example.invalid/first';
    const replacement = 'https://example.invalid/second';
    final local = _Frames();
    final first = _Frames();
    final second = _Frames();
    final cache = PaintingBinding.instance.imageCache;
    cache.putIfAbsent(FileImage(File(localPath)), () => local);
    cache.putIfAbsent(const NetworkImage(url), () => first);
    cache.putIfAbsent(const NetworkImage(replacement), () => second);
    final localImage =
        (await tester.runAsync(() => createTestImage(width: 3, height: 3)))!;
    final firstImage =
        (await tester.runAsync(() => createTestImage(width: 4, height: 4)))!;
    final secondImage =
        (await tester.runAsync(() => createTestImage(width: 5, height: 5)))!;
    local.show(localImage);

    Widget app(String? photoUrl) => MaterialApp(
        home: Center(
            child: SizedBox(
                width: 200,
                height: 200,
                child: JourneyPhoto(
                    key: const ValueKey('capture-uuid'),
                    capture: JourneyCapture(
                        id: 'capture-uuid',
                        spotId: 'spot',
                        spotSlug: 'slug',
                        spotName: 'Spot',
                        capturedAt: DateTime.utc(2026),
                        photoStoragePath: 'owner/capture/original.jpg',
                        localPhotoPathFallback: localPath,
                        photoUrl: photoUrl)))));
    List<int?> paintedWidths() => tester
        .widgetList<RawImage>(find.byType(RawImage))
        .map((image) => image.image?.width)
        .toList();

    await tester.pumpWidget(app(null));
    expect(paintedWidths(), [3]);
    expect(tester.getSize(find.byType(RawImage)), const Size(200, 200));
    final localElement = tester.element(find.byType(Image));
    final photoState = tester.state(find.byType(JourneyPhoto));
    await tester.pumpWidget(app(url));
    expect(tester.state(find.byType(JourneyPhoto)), same(photoState));
    expect(
        tester.element(
            find.byWidgetPredicate((w) => w is Image && w.image is FileImage)),
        same(localElement));
    expect(paintedWidths(), [3]);
    await tester.pump(const Duration(milliseconds: 16));
    expect(paintedWidths(), [3]);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    first.show(firstImage);
    await tester.pump();
    expect(paintedWidths(), [3, 4]);
    final networkElement = tester.element(
        find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage));
    await tester.pumpWidget(app(replacement));
    expect(paintedWidths(), [3, 4]);
    expect(
        tester.element(find
            .byWidgetPredicate((w) => w is Image && w.image is NetworkImage)),
        same(networkElement));
    await tester.pump(const Duration(milliseconds: 16));
    expect(paintedWidths(), [3, 4]);
    second.show(secondImage);
    await tester.pump();
    expect(paintedWidths(), [3, 5]);
    await tester.pumpWidget(const SizedBox());
    cache.clear();
    cache.clearLiveImages();
  });
}
