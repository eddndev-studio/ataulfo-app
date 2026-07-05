import 'package:ataulfo/core/media/attachment_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('image/* es imagen', () {
    expect(attachmentKindForMime('image/png'), AttachmentKind.image);
    expect(attachmentKindForMime('image/jpeg'), AttachmentKind.image);
    expect(attachmentKindForMime('image/webp'), AttachmentKind.image);
  });

  test('video/* es video', () {
    expect(attachmentKindForMime('video/mp4'), AttachmentKind.video);
    expect(attachmentKindForMime('video/webm'), AttachmentKind.video);
  });

  test('audio/* es audio', () {
    expect(attachmentKindForMime('audio/ogg'), AttachmentKind.audio);
    expect(
      attachmentKindForMime('audio/ogg; codecs=opus'),
      AttachmentKind.audio,
    );
    expect(attachmentKindForMime('audio/mpeg'), AttachmentKind.audio);
  });

  test('el resto es documento', () {
    expect(attachmentKindForMime('application/pdf'), AttachmentKind.document);
    expect(attachmentKindForMime('text/plain'), AttachmentKind.document);
    expect(attachmentKindForMime(''), AttachmentKind.document);
    // Un mime malformado no debe adivinar: cae a documento.
    expect(attachmentKindForMime('imagen'), AttachmentKind.document);
  });

  test('tolera mayúsculas y espacios del wire', () {
    expect(attachmentKindForMime(' IMAGE/PNG '), AttachmentKind.image);
    expect(attachmentKindForMime('Audio/Ogg'), AttachmentKind.audio);
  });
}
