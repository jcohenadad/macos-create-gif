#!/bin/bash
# Create GIF — Finder Quick Action
# Selected images arrive as arguments. Frames are ordered by file name.
[ $# -eq 0 ] && exit 0
/usr/bin/osascript -l JavaScript - "$@" <<'JXA'
ObjC.import('Foundation');
ObjC.import('AppKit');
ObjC.import('ImageIO');

// Refreshes the output-size label while the user types the percentage
var updateSize = function () {};
ObjC.registerSubclass({
  name: 'CreateGifFieldDelegate',
  protocols: ['NSTextFieldDelegate'],
  methods: {
    'controlTextDidChange:': { types: ['void', ['id']], implementation: function () { updateSize(); } }
  }
});

// [width, height] in pixels as displayed (EXIF orientation applied), or null
function imageSize(f) {
  var src = $.CGImageSourceCreateWithURL($.NSURL.fileURLWithPath(f), $());
  if (!src || src.isNil && src.isNil()) return null;
  var p = ObjC.deepUnwrap(ObjC.castRefToObject($.CGImageSourceCopyPropertiesAtIndex(src, 0, $())));
  if (!p || !p.PixelWidth || !p.PixelHeight) return null;
  return p.Orientation >= 5 ? [p.PixelHeight, p.PixelWidth] : [p.PixelWidth, p.PixelHeight];
}

// Size after scaling to pct % (longest side rounded, the other kept in proportion)
function scaledSize(s, pct) {
  var long = Math.max(1, Math.round(Math.max(s[0], s[1]) * pct / 100));
  var short = Math.max(1, Math.round(Math.min(s[0], s[1]) * long / Math.max(s[0], s[1])));
  return s[0] >= s[1] ? [long, short] : [short, long];
}

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
  var view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 260, 84));
  function label(y, text) {
    var l = $.NSTextField.labelWithString(text);
    l.frame = $.NSMakeRect(0, y, 260, 17);
    view.addSubview(l);
    return l;
  }
  function field(y, text, def) {
    label(y + 3, text);
    var t = $.NSTextField.alloc.initWithFrame($.NSMakeRect(175, y, 85, 22));
    t.stringValue = String(def);
    view.addSubview(t);
    return t;
  }
  function num(t, def) {
    var v = parseFloat(t.stringValue.js.replace(',', '.').replace('%', ''));
    return v > 0 ? v : def;
  }
  var delayField = field(60, 'Seconds per frame:', delay);
  var scaleField = field(30, 'Resolution (% of original):', scale);
  var sizeLabel = label(2, '');
  delayField.nextKeyView = scaleField;
  scaleField.nextKeyView = delayField;

  // Output size, shown for the first image (noted if the images differ in size)
  var sizes = files.map(imageSize).filter(Boolean);
  var first = sizes[0];
  var mixed = sizes.some(function (s) { return s[0] !== first[0] || s[1] !== first[1]; });
  updateSize = function () {
    if (!first) { sizeLabel.stringValue = ''; return; }
    var o = scaledSize(first, Math.min(num(scaleField, scale), 100));
    sizeLabel.stringValue = 'Output size' + (mixed ? ' (first image)' : '') + ': ' + o[0] + ' × ' + o[1] + ' px';
  };
  updateSize();
  var delegate = $.CreateGifFieldDelegate.alloc.init;
  scaleField.delegate = delegate;
  alert.accessoryView = view;
  alert.window.initialFirstResponder = delayField;
  alert.layout;
  alert.window.level = $.NSFloatingWindowLevel;
  alert.window.center;
  alert.window.orderFrontRegardless;
  if (alert.runModal !== $.NSAlertFirstButtonReturn) return; // user cancelled
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
    var size = imageSize(f);
    if (!size) return;
    var maxPx = Math.max.apply(null, scaledSize(size, scale));
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
