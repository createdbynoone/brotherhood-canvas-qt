#include "mac.h"

#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QWindow>

#import <AVFoundation/AVFoundation.h>
#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <IOKit/IOKitLib.h>
#import <Security/Security.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

namespace Mac {

static NSString *ns(const QString &s) { return s.toNSString(); }
static NSURL *fileUrl(const QString &p) { return [NSURL fileURLWithPath:ns(p)]; }

// ── Crypto ───────────────────────────────────────────────────────────

QString machineId() {
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
    if (!svc) return QStringLiteral("unknown-machine");
    CFTypeRef uuid = IORegistryEntryCreateCFProperty(svc, CFSTR("IOPlatformUUID"), kCFAllocatorDefault, 0);
    IOObjectRelease(svc);
    if (!uuid) return QStringLiteral("unknown-machine");
    QString out = QString::fromCFString((CFStringRef)uuid);
    CFRelease(uuid);
    return out;
}

bool pbkdf2Sha512(const QByteArray &pass, const QByteArray &salt, quint32 iterations, int keyLen, QByteArray *out) {
    out->resize(keyLen);
    int rc = CCKeyDerivationPBKDF(kCCPBKDF2, pass.constData(), pass.size(),
                                  reinterpret_cast<const uint8_t *>(salt.constData()), salt.size(),
                                  kCCPRFHmacAlgSHA512, iterations,
                                  reinterpret_cast<uint8_t *>(out->data()), keyLen);
    return rc == kCCSuccess;
}

bool pbkdf2Sha256(const QByteArray &pass, const QByteArray &salt, quint32 iterations, int keyLen, QByteArray *out) {
    out->resize(keyLen);
    int rc = CCKeyDerivationPBKDF(kCCPBKDF2, pass.constData(), pass.size(),
                                  reinterpret_cast<const uint8_t *>(salt.constData()), salt.size(),
                                  kCCPRFHmacAlgSHA256, iterations,
                                  reinterpret_cast<uint8_t *>(out->data()), keyLen);
    return rc == kCCSuccess;
}

QByteArray hmacSha256(const QByteArray &key, const QByteArray &data) {
    QByteArray mac(CC_SHA256_DIGEST_LENGTH, 0);
    CCHmac(kCCHmacAlgSHA256, key.constData(), key.size(), data.constData(), data.size(), mac.data());
    return mac;
}

QByteArray sha256(const QByteArray &data) {
    QByteArray d(CC_SHA256_DIGEST_LENGTH, 0);
    CC_SHA256(data.constData(), (CC_LONG)data.size(), reinterpret_cast<unsigned char *>(d.data()));
    return d;
}

// ── Images ───────────────────────────────────────────────────────────────

static QImage toQImage(CGImageRef cg) {
    if (!cg) return {};
    const int w = (int)CGImageGetWidth(cg), h = (int)CGImageGetHeight(cg);
    QImage img(w, h, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(img.bits(), w, h, 8, img.bytesPerLine(), cs,
                                             kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(cs);
    if (!ctx) return {};
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    CGContextRelease(ctx);
    return img;
}

static CGImageSourceRef openSource(const QString &path) {
    return CGImageSourceCreateWithURL((__bridge CFURLRef)fileUrl(path), nullptr);
}

ImageProps imageProps(const QString &path) {
    ImageProps p;
    CGImageSourceRef src = openSource(path);
    if (!src) return p;
    CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(src, 0, nullptr);
    if (props) {
        NSDictionary *d = (__bridge NSDictionary *)props;
        p.w = [d[(__bridge id)kCGImagePropertyPixelWidth] intValue];
        p.h = [d[(__bridge id)kCGImagePropertyPixelHeight] intValue];
        id o = d[(__bridge id)kCGImagePropertyOrientation];
        p.orientation = o ? [o intValue] : 1;
        p.ok = p.w > 0 && p.h > 0;
        CFRelease(props);
    }
    CFRelease(src);
    return p;
}

static CGImageRef thumbnailRef(const QString &path, int maxPixel) {
    CGImageSourceRef src = openSource(path);
    if (!src) return nullptr;
    NSDictionary *opts = @{(__bridge id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                           (__bridge id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                           (__bridge id)kCGImageSourceThumbnailMaxPixelSize: @(maxPixel)};
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(src);
    return cg;  // +1
}

static bool writeJpeg(CGImageRef cg, NSMutableData *data, double quality) {
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data,
                                                                  (__bridge CFStringRef)UTTypeJPEG.identifier, 1, nullptr);
    if (!dest) return false;
    NSDictionary *props = @{(__bridge id)kCGImageDestinationLossyCompressionQuality: @(quality)};
    CGImageDestinationAddImage(dest, cg, (__bridge CFDictionaryRef)props);
    bool ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    return ok;
}

bool writeNormalizedJpeg(const QString &src, const QString &dst, int maxEdge, double quality) {
    CGImageRef cg = thumbnailRef(src, maxEdge);
    if (!cg) return false;
    NSMutableData *data = [NSMutableData data];
    bool ok = writeJpeg(cg, data, quality);
    CGImageRelease(cg);
    if (!ok) return false;
    return [data writeToFile:ns(dst) atomically:YES];
}

QImage downsample(const QString &path, int maxPixel) {
    CGImageRef cg = thumbnailRef(path, maxPixel);
    QImage img = toQImage(cg);
    if (cg) CGImageRelease(cg);
    return img;
}

QImage videoFrame(const QString &path, int maxSide) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileUrl(path) options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    gen.maximumSize = CGSizeMake(maxSide, maxSide);
    double dur = CMTimeGetSeconds(asset.duration);
    if (!(dur > 0)) dur = 2;
    CMTime t = CMTimeMakeWithSeconds(MIN(1.0, dur / 3.0), 600);
    __block QImage out;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [gen generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:t]]
                              completionHandler:^(CMTime, CGImageRef image, CMTime, AVAssetImageGeneratorResult result, NSError *) {
        if (result == AVAssetImageGeneratorSucceeded && image) out = toQImage(image);
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC));
    return out;
}

VideoProps videoProps(const QString &path) {
    VideoProps p;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileUrl(path) options:nil];
    NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (tracks.count == 0) return p;
    CGSize s = CGSizeApplyAffineTransform(tracks[0].naturalSize, tracks[0].preferredTransform);
    p.w = (int)fabs(s.width); p.h = (int)fabs(s.height);
    const double d = CMTimeGetSeconds(asset.duration);
    p.seconds = d > 0 ? d : 0;
    p.ok = p.w > 0 && p.h > 0;
    return p;
}

QImage pdfPage(const QString &path, int maxSide, int *pages) {
    CGPDFDocumentRef doc = CGPDFDocumentCreateWithURL((__bridge CFURLRef)fileUrl(path));
    if (!doc) return {};
    if (pages) *pages = (int)CGPDFDocumentGetNumberOfPages(doc);
    CGPDFPageRef page = CGPDFDocumentGetPage(doc, 1);
    if (!page) { CGPDFDocumentRelease(doc); return {}; }
    CGRect box = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    const int rot = CGPDFPageGetRotationAngle(page);
    const bool swap = rot == 90 || rot == 270;
    const double pw = swap ? box.size.height : box.size.width, ph = swap ? box.size.width : box.size.height;
    if (pw < 1 || ph < 1) { CGPDFDocumentRelease(doc); return {}; }
    const double scale = maxSide / MAX(pw, ph);
    const int w = MAX(1, (int)llround(pw * scale)), h = MAX(1, (int)llround(ph * scale));
    QImage img(w, h, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::white);
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(img.bits(), w, h, 8, img.bytesPerLine(), cs,
                                             kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(cs);
    if (ctx) {
        CGAffineTransform t = CGPDFPageGetDrawingTransform(page, kCGPDFCropBox, CGRectMake(0, 0, w, h), 0, true);
        CGContextConcatCTM(ctx, t);
        CGContextDrawPDFPage(ctx, page);
        CGContextRelease(ctx);
    } else img = QImage();
    CGPDFDocumentRelease(doc);
    return img;
}

QString mediaInfo(const QString &path) {
    const QString ext = QFileInfo(path).suffix().toLower();
    static const QStringList video = {"mp4", "mov", "webm", "m4v"};
    if (video.contains(ext)) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileUrl(path) options:nil];
        NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
        if (tracks.count == 0) return {};
        CGSize s = tracks[0].naturalSize;
        int secs = (int)llround(CMTimeGetSeconds(asset.duration));
        return QStringLiteral("%1 × %2 · %3:%4").arg((int)fabs(s.width)).arg((int)fabs(s.height))
            .arg(secs / 60).arg(secs % 60, 2, 10, QChar('0'));
    }
    ImageProps p = imageProps(path);
    return p.ok ? QStringLiteral("%1 × %2").arg(p.w).arg(p.h) : QString();
}

QByteArray composeCover(const QString &path, int w, int h, double quality) {
    CGImageSourceRef src = openSource(path);
    if (!src) return {};
    NSDictionary *opts = @{(__bridge id)kCGImageSourceShouldCacheImmediately: @YES};
    CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(src);
    if (!img) return {};
    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(nullptr, w, h, 8, 0, cs, kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(cs);
    if (!ctx) { CGImageRelease(img); return {}; }
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    const double scale = MAX((double)w / CGImageGetWidth(img), (double)h / CGImageGetHeight(img));
    const double sw = CGImageGetWidth(img) * scale, sh = CGImageGetHeight(img) * scale;
    CGContextDrawImage(ctx, CGRectMake((w - sw) / 2, (h - sh) / 2, sw, sh), img);
    CGImageRef outImg = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGImageRelease(img);
    if (!outImg) return {};
    NSMutableData *data = [NSMutableData data];
    bool ok = writeJpeg(outImg, data, quality);
    CGImageRelease(outImg);
    if (!ok) return {};
    return QByteArray(reinterpret_cast<const char *>(data.bytes), (qsizetype)data.length);
}

// ── Files ────────────────────────────────────────────────────────────────

bool trashItem(const QString &path) {
    NSError *err = nil;
    if ([[NSFileManager defaultManager] trashItemAtURL:fileUrl(path) resultingItemURL:nil error:&err]) return true;
    return !QFileInfo::exists(path);
}

void revealInFinder(const QString &path) {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[fileUrl(path)]];
}

// ── Window ───────────────────────────────────────────────────────────────

void setDarkAppearance() {
    [NSApp setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
}

void setAccessoryPolicy() { [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory]; }

void styleWindow(QWindow *w) {
    NSView *view = (__bridge NSView *)reinterpret_cast<void *>(w->winId());
    NSWindow *win = view.window;
    if (!win) return;
    win.titlebarAppearsTransparent = YES;
    win.titleVisibility = NSWindowTitleHidden;
    win.styleMask |= NSWindowStyleMaskFullSizeContentView;
    win.backgroundColor = [NSColor colorWithSRGBRed:11 / 255.0 green:11 / 255.0 blue:10 / 255.0 alpha:1];
    win.movableByWindowBackground = NO;
}

bool reduceMotion() { return [[NSWorkspace sharedWorkspace] accessibilityDisplayShouldReduceMotion]; }

void zoomWindow(QWindow *w) {
    NSView *view = (__bridge NSView *)reinterpret_cast<void *>(w->winId());
    [view.window performZoom:nil];
}

void installTitleBarDrag(QWindow *w, std::function<bool(double, double)> isDragPoint) {
    NSView *view = (__bridge NSView *)reinterpret_cast<void *>(w->winId());
    NSWindow *win = view.window;
    if (!win) return;
    // A local monitor sees the NSEvent before Qt's view does, so performWindowDragWithEvent: gets the real
    // mouse-down it requires (Qt delivers its own events asynchronously, too late for that).
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent *(NSEvent *e) {
        if (e.window != win) return e;
        const NSPoint p = e.locationInWindow;
        const double x = p.x, y = view.bounds.size.height - p.y;
        if (y < 0 || y > 120 || !isDragPoint(x, y)) return e;
        if (e.clickCount == 2) { [win performZoom:nil]; return nil; }
        [win performWindowDragWithEvent:e];
        return nil;
    }];
}

}  // namespace Mac
