#!/bin/bash
# Create GIF — Finder Quick Action
# Selected images arrive as arguments. Frames are ordered by file name.
[ $# -eq 0 ] && exit 0
/usr/bin/osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('Foundation');
ObjC.import('AppKit');
ObjC.import('ImageIO');
ObjC.import('CoreGraphics');

function run(argv) {
  var app = Application.currentApplication();
  app.includeStandardAdditions = true;

  var files = argv.slice().sort(function (a, b) {
    return a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' });
  });
  if (files.length === 0) return;

  // Ask for frame delay and resolution (% of original size) in one dialog
  var delay = 0.5, scale = 50;
  // Launched from a background Quick Action, so become a (Dock-less) app and
  // float the dialog above Finder; macOS may refuse to bring it to the front otherwise
  $.NSApplication.sharedApplication;
  $.NSApp.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
  $.NSApp.activateIgnoringOtherApps(true);
  var alert = $.NSAlert.alloc.init;
  alert.messageText = 'Create GIF';
  alert.informativeText = files.length + ' images';
  alert.addButtonWithTitle('Create');
  alert.addButtonWithTitle('Cancel');
  var view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 260, 56));
  function field(y, label, def) {
    var l = $.NSTextField.labelWithString(label);
    l.frame = $.NSMakeRect(0, y + 3, 170, 17);
    view.addSubview(l);
    var t = $.NSTextField.alloc.initWithFrame($.NSMakeRect(175, y, 85, 22));
    t.stringValue = String(def);
    view.addSubview(t);
    return t;
  }
  var delayField = field(32, 'Seconds per frame:', delay);
  var scaleField = field(0, 'Resolution (% of original):', scale);
  delayField.nextKeyView = scaleField;
  scaleField.nextKeyView = delayField;
  alert.accessoryView = view;
  alert.window.initialFirstResponder = delayField;
  alert.layout;
  alert.window.level = $.NSFloatingWindowLevel;
  alert.window.center;
  alert.window.orderFrontRegardless;
  if (alert.runModal !== $.NSAlertFirstButtonReturn) return; // user cancelled
  function num(t, def) {
    var v = parseFloat(t.stringValue.js.replace(',', '.').replace('%', ''));
    return v > 0 ? v : def;
  }
  delay = num(delayField, delay);
  scale = Math.min(num(scaleField, scale), 100);

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

  function thumbOpts(maxPx) {
    return $.NSDictionary.dictionaryWithObjectsForKeys(
      $([$.NSNumber.numberWithBool(true), $.NSNumber.numberWithBool(true), $.NSNumber.numberWithInt(maxPx)]),
      $([$('kCGImageSourceCreateThumbnailFromImageAlways'), $('kCGImageSourceCreateThumbnailWithTransform'), $('kCGImageSourceThumbnailMaxPixelSize')]));
  }

  var added = 0;
  files.forEach(function (f) {
    var src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(f), $());
    if (!src || src.isNil && src.isNil()) return;
    // Longest side of the original image, scaled by the chosen percentage
    var full = $.CGImageSourceCreateImageAtIndex(src, 0, $());
    if (!full || full.isNil && full.isNil()) return;
    var maxPx = Math.max(1, Math.round(Math.max($.CGImageGetWidth(full), $.CGImageGetHeight(full)) * scale / 100));
    var img = $.CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts(maxPx));
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
