#!/bin/bash
# Create GIF — Finder Quick Action
# Selected images arrive as arguments. Frames are ordered by file name.
[ $# -eq 0 ] && exit 0
/usr/bin/osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('Foundation');
ObjC.import('ImageIO');

function run(argv) {
  var app = Application.currentApplication();
  app.includeStandardAdditions = true;

  var files = argv.slice().sort(function (a, b) {
    return a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' });
  });
  if (files.length === 0) return;

  // Ask for frame delay and max size
  var delay = 0.5, maxPx = 800;
  try {
    var r = app.displayDialog('Seconds per frame (' + files.length + ' images):', {
      defaultAnswer: '0.5', withTitle: 'Create GIF',
      buttons: ['Cancel', 'Create'], defaultButton: 'Create', cancelButton: 'Cancel'
    });
    var d = parseFloat(String(r.textReturned).replace(',', '.'));
    if (d > 0) delay = d;
  } catch (e) {
    if (e.errorNumber === -128) return; // user cancelled
  }

  // Output path: <folder of first image>/animation.gif (unique)
  var fm = $.NSFileManager.defaultManager;
  var dir = $(files[0]).stringByDeletingLastPathComponent.js;
  var out = dir + '/animation.gif', i = 2;
  while (fm.fileExistsAtPath(out)) { out = dir + '/animation ' + i + '.gif'; i++; }

  var dest = $.CGImageDestinationCreateWithURL($.NSURL.fileURLWithPath(out), $('com.compuserve.gif'), files.length, $());

  var gifFile = $.NSDictionary.dictionaryWithObjectForKey(
    $.NSDictionary.dictionaryWithObjectForKey($.NSNumber.numberWithInt(0), $('LoopCount')), $('{GIF}'));
  $.CGImageDestinationSetProperties(dest, gifFile);

  var gifFrame = $.NSDictionary.dictionaryWithObjectForKey(
    $.NSDictionary.dictionaryWithObjectsForKeys(
      $([$.NSNumber.numberWithDouble(delay), $.NSNumber.numberWithDouble(delay)]),
      $([$('DelayTime'), $('UnclampedDelayTime')])), $('{GIF}'));

  var thumbOpts = $.NSDictionary.dictionaryWithObjectsForKeys(
    $([$.NSNumber.numberWithBool(true), $.NSNumber.numberWithBool(true), $.NSNumber.numberWithInt(maxPx)]),
    $([$('kCGImageSourceCreateThumbnailFromImageAlways'), $('kCGImageSourceCreateThumbnailWithTransform'), $('kCGImageSourceThumbnailMaxPixelSize')]));

  var added = 0;
  files.forEach(function (f) {
    var src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(f), $());
    if (!src || src.isNil && src.isNil()) return;
    var img = $.CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts);
    if (!img || img.isNil && img.isNil()) return;
    $.CGImageDestinationAddImage(dest, img, gifFrame);
    added++;
  });

  if (added > 0 && $.CGImageDestinationFinalize(dest)) {
    app.displayNotification(added + ' frames → ' + out.split('/').pop(), { withTitle: 'GIF created' });
  } else {
    app.displayAlert('Create GIF failed', { message: 'Could not build the GIF from the selected files.' });
  }
}
JXA
