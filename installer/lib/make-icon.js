// make-icon.js – baut das Symbol der Start-Apps (JavaScript for Automation, nur macOS-Bordmittel).
// Das WoW-Symbol aus dem Spielordner kommt auf eine dunkle Kachel im Raster von macOS 26+
// (sonst steckt macOS es in eine graue Kachel). Variante "leistung": zusätzlich ein grüner Blitz.
// Aufruf: osascript -l JavaScript make-icon.js QUELLE(.icns/.png) ZIEL.png [normal|leistung]
ObjC.import('AppKit');

function rect(x, y, w, h) { return $.NSMakeRect(x, y, w, h); }
function pt(x, y) { return $.NSMakePoint(x, y); }
function rgb(r, g, b, a) {
  return $.NSColor.colorWithSRGBRedGreenBlueAlpha(r / 255, g / 255, b / 255, a === undefined ? 1 : a);
}
function fillPath(path, color) { color.setFill; path.fill; }

function run(argv) {
  if (argv.length < 2) throw new Error('Aufruf: make-icon.js QUELLE ZIEL.png [normal|leistung]');
  var src = argv[0], out = argv[1], variant = argv[2] || 'normal';
  var base = $.NSImage.alloc.initWithContentsOfFile(src);
  if (base.isNil()) throw new Error('Bild nicht lesbar: ' + src);

  var S = 1024;
  var rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
    null, S, S, 8, 4, true, false, 'NSDeviceRGBColorSpace', 0, 0);
  if (rep.isNil()) throw new Error('Bildpuffer nicht angelegt');
  var ctx = $.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep);
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext(ctx);
  ctx.setImageInterpolation(3);   // NSImageInterpolationHigh

  // Kachel: 824 x 824 Pixel mit 100 Pixel Rand, Ecken ca. 22 % (App-Symbol-Raster von macOS)
  var plate = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(rect(100, 100, 824, 824), 185, 185);
  $.NSGradient.alloc.initWithStartingColorEndingColor(rgb(58, 62, 74), rgb(16, 17, 22)).drawInBezierPathAngle(plate, -90);

  // WoW-Symbol mittig in die Kachel (Quelle: Symbol aus dem Spielordner des Nutzers)
  base.drawInRectFromRectOperationFraction(rect(162, 162, 700, 700), rect(0, 0, 0, 0), 2, 1.0);   // 2 = SourceOver

  if (variant === 'leistung') {
    // grüne Plakette mit weißem Blitz unten rechts
    var cx = 718, cy = 306, r = 178;
    fillPath($.NSBezierPath.bezierPathWithOvalInRect(rect(cx - r - 4, cy - r - 14, 2 * r + 8, 2 * r + 8)), rgb(0, 0, 0, 0.35));
    fillPath($.NSBezierPath.bezierPathWithOvalInRect(rect(cx - r, cy - r, 2 * r, 2 * r)), rgb(255, 255, 255));
    var disc = $.NSBezierPath.bezierPathWithOvalInRect(rect(cx - r + 18, cy - r + 18, 2 * r - 36, 2 * r - 36));
    $.NSGradient.alloc.initWithStartingColorEndingColor(rgb(96, 222, 110), rgb(22, 148, 54)).drawInBezierPathAngle(disc, -90);
    var k = r * 0.74;
    var pts = [[0.20, 0.95], [-0.52, -0.08], [-0.06, -0.08], [-0.24, -0.95], [0.52, 0.14], [0.06, 0.14]];
    var bolt = $.NSBezierPath.bezierPath;
    for (var i = 0; i < pts.length; i++) {
      var q = pt(cx + pts[i][0] * k, cy + pts[i][1] * k);
      if (i === 0) bolt.moveToPoint(q); else bolt.lineToPoint(q);
    }
    bolt.closePath;
    fillPath(bolt, rgb(255, 255, 255));
  }

  ctx.flushGraphics;
  $.NSGraphicsContext.restoreGraphicsState;
  var data = rep.representationUsingTypeProperties(4, $({}));   // 4 = PNG
  if (data.isNil() || !data.writeToFileAtomically(out, true)) throw new Error('PNG nicht geschrieben: ' + out);
  return out;
}
