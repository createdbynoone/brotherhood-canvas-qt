#include "mediaprovider.h"

#include "../platform/mac.h"

#include <QCache>
#include <QDir>
#include <QFileInfo>
#include <QImage>
#include <QMutex>
#include <QQuickImageResponse>
#include <QQuickTextureFactory>
#include <QRunnable>
#include <QThread>
#include <QUrl>
#include <atomic>

namespace {

QMutex gMutex;
std::atomic<int> gPending{0};
QString gRoot;
QCache<QString, QImage> gCache(128 * 1024 * 1024);      // cost = bytes

QImage cached(const QString &key) {
    QMutexLocker l(&gMutex);
    if (const QImage *i = gCache.object(key)) return *i;
    return {};
}
void store(const QString &key, const QImage &img) {
    QMutexLocker l(&gMutex);
    gCache.insert(key, new QImage(img), int(img.sizeInBytes()));
}

class Response : public QQuickImageResponse, public QRunnable {
public:
    Response(QString key, QString rel, int side) : m_key(std::move(key)), m_rel(std::move(rel)), m_side(side) { setAutoDelete(false); }
    QQuickTextureFactory *textureFactory() const override { return QQuickTextureFactory::textureFactoryForImage(m_image); }
    void cancel() override { m_cancelled = true; }

    void run() override {
        if (!m_cancelled) m_image = load();
        emit finished();
        --gPending;
    }

private:
    QImage load() {
        QImage hit = cached(m_key);
        if (!hit.isNull()) return hit;
        QString root;
        { QMutexLocker l(&gMutex); root = gRoot; }
        if (root.isEmpty()) return {};
        const QString base = QDir(root).canonicalPath();
        const QString abs = QDir::cleanPath(base + "/" + m_rel);
        if (!abs.startsWith(base + "/")) return {};           // never read outside the vault
        const QString ext = QFileInfo(abs).suffix().toLower();
        QImage img;
        if (ext == "pdf") img = Mac::pdfPage(abs, m_side);
        else if (ext == "mp4" || ext == "mov" || ext == "webm" || ext == "m4v" || ext == "mkv" || ext == "avi") img = Mac::videoFrame(abs, m_side);
        else img = Mac::downsample(abs, m_side);
        if (!img.isNull()) store(m_key, img);
        return img;
    }

    QString m_key, m_rel;
    int m_side;
    QImage m_image;
    std::atomic<bool> m_cancelled{false};
};

}  // namespace

MediaProvider::MediaProvider() { m_pool.setMaxThreadCount(qMax(2, QThread::idealThreadCount() - 2)); }

int MediaProvider::pending() { return gPending.load(); }

void MediaProvider::dropCache() { QMutexLocker l(&gMutex); gCache.clear(); }

void MediaProvider::setRoot(const QString &vaultPath) {
    QMutexLocker l(&gMutex);
    gRoot = vaultPath;
    gCache.clear();
}

QQuickImageResponse *MediaProvider::requestImageResponse(const QString &id, const QSize &) {
    const int q = id.indexOf('?');
    const QString enc = q < 0 ? id : id.left(q);
    int side = 1024;
    if (q >= 0) {
        const QString tail = id.mid(q + 1);
        if (tail.startsWith("s=")) side = qBound(64, tail.mid(2).toInt(), 8192);
    }
    const QString rel = QUrl::fromPercentEncoding(enc.toUtf8());
    auto *r = new Response(rel + "?" + QString::number(side), rel, side);
    ++gPending;
    m_pool.start(r);
    return r;
}
