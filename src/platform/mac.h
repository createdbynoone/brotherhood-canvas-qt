#pragma once
#include <QByteArray>
#include <QImage>
#include <QString>
#include <functional>

class QWindow;

// Thin wrappers over Apple frameworks (CommonCrypto, ImageIO, AVFoundation,
// AppKit). Everything above this layer stays portable C++/Qt.
namespace Mac {

// ── Crypto ────────────────────────────────────────────────────
QString machineId();
bool pbkdf2Sha512(const QByteArray &pass, const QByteArray &salt, quint32 iterations, int keyLen, QByteArray *out);
bool pbkdf2Sha256(const QByteArray &pass, const QByteArray &salt, quint32 iterations, int keyLen, QByteArray *out);
QByteArray hmacSha256(const QByteArray &key, const QByteArray &data);
QByteArray sha256(const QByteArray &data);

// ── Images / video ───────────────────────────────────────────────────────
struct ImageProps { bool ok = false; int w = 0; int h = 0; int orientation = 1; };
ImageProps imageProps(const QString &path);
/// Re-encodes as JPEG with EXIF rotation baked in, long side <= maxEdge.
bool writeNormalizedJpeg(const QString &src, const QString &dst, int maxEdge, double quality);
/// Decoded bitmap, long side <= maxPixel, orientation applied. Null on failure.
QImage downsample(const QString &path, int maxPixel);
QImage videoFrame(const QString &path, int maxSide);
/// Natural (display) size and duration of a video file, preferred transform applied. ok=false when unreadable.
struct VideoProps { bool ok = false; int w = 0; int h = 0; double seconds = 0; };
VideoProps videoProps(const QString &path);
/// First page of a PDF rendered on white, long side == maxSide. Null on failure. `pages` receives the page count.
QImage pdfPage(const QString &path, int maxSide, int *pages = nullptr);
/// "W x H" for images, "W x H . m:ss" for video (empty when unreadable).
QString mediaInfo(const QString &path);
/// Cover-crop (never letterbox) composite as JPEG data.
QByteArray composeCover(const QString &path, int w, int h, double quality);

// ── Files ────────────────────────────────────────────────────────────────
bool trashItem(const QString &path);       // volume-correct Trash; true when the file is gone
void revealInFinder(const QString &path);

// ── Window ───────────────────────────────────────────────────────────────
void styleWindow(QWindow *w);              // transparent title bar, content under it, dark appearance
void zoomWindow(QWindow *w);
/// Custom title bar: a mouse-down for which `isDragPoint(x, y)` (window coordinates, top-left origin) is true
/// starts a native window drag (double click zooms). The click is taken before Qt sees it.
void installTitleBarDrag(QWindow *w, std::function<bool(double, double)> isDragPoint);
/// Trackpad pinch as plain numbers: (window x, window y from the top-left, magnification delta, NSEventPhase).
/// The events are swallowed so Qt's own touch / native-gesture handling never sees them: Qt Quick's PinchHandler
/// also reacts to resting fingers and to the magnify noise macOS mixes into scrolls and clicks.
void installMagnify(QWindow *w, std::function<void(double, double, double, int)> cb);
void setDarkAppearance();
void setAccessoryPolicy();                  // no Dock icon, never activates (automated test runs)
bool reduceMotion();                        // System Settings > Accessibility > Display > Reduce motion

}  // namespace Mac
