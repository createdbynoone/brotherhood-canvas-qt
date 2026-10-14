#pragma once
#include <QQuickAsyncImageProvider>
#include <QThreadPool>

// image://media/<percent-encoded vault-relative path>?s=<longest side in px>
// Images are decoded straight to the requested size by ImageIO, videos use their poster frame, PDFs their first page.
// Decoding happens on a private thread pool; finished bitmaps sit in a byte-limited cache so panning back is instant.
class MediaProvider : public QQuickAsyncImageProvider {
public:
    MediaProvider();
    static void setRoot(const QString &vaultPath);
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

private:
    QThreadPool m_pool;
};
