#include "sceneexport.h"

#include "boardmodel.h"
#include "mediaprovider.h"

#include <QGuiApplication>
#include <QPainter>
#include <QPdfWriter>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickView>
#include <QScreen>
#include <QUrl>

SceneExport::SceneExport(const Params &p, QObject *parent) : QObject(parent), m_p(p) {
    m_timer.setInterval(100);
    connect(&m_timer, &QTimer::timeout, this, &SceneExport::poll);
}

SceneExport::~SceneExport() {
    delete m_view;
    delete m_engine;
}

bool SceneExport::start(QString *error) {
    const double dpr = QGuiApplication::primaryScreen() ? QGuiApplication::primaryScreen()->devicePixelRatio() : 2.0;
    // device pixels per world unit: 2x, less for a huge board (6144 px on the long side at most)
    m_target = qMin(2.0, 6144.0 / qMax(m_p.box.width(), m_p.box.height()));
    m_scale = m_target / dpr;

    m_engine = new QQmlEngine;
    m_engine->addImageProvider("media", new MediaProvider);
    auto *ctx = m_engine->rootContext();
    ctx->setContextProperty("board", m_p.board);
    ctx->setContextProperty("app", m_p.app);
    ctx->setContextProperty("brandFamily", m_p.brand);
    ctx->setContextProperty("markerFamily", m_p.marker);

    m_view = new QQuickView(m_engine, nullptr);
    m_view->setFlags(Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus | Qt::WindowTransparentForInput);
    m_view->setColor(QColor("#0B0B0A"));
    m_view->setResizeMode(QQuickView::SizeViewToRootObject);
    m_view->setInitialProperties({{"box", m_p.box}, {"s", m_scale}, {"only", m_p.only}, {"onlyEdges", m_p.onlyEdges}, {"pattern", m_p.pattern}});
    m_view->setSource(QUrl(QStringLiteral("qrc:/qt/qml/Canvas/qml/canvas/ExportScene.qml")));
    if (m_view->status() != QQuickView::Ready) {
        if (error) { QStringList e; for (const auto &x : m_view->errors()) e << x.toString(); *error = e.join('\n'); }
        return false;
    }
    m_view->setOpacity(0);              // laid out and rendered like any window, but never seen
    m_view->show();
    m_timer.start();
    return true;
}

// Ready when the images have all been decoded and a few frames have passed without anything new being asked for
void SceneExport::poll() {
    ++m_ticks;
    m_calm = MediaProvider::pending() == 0 ? m_calm + 1 : 0;
    if ((m_calm >= 5 && m_ticks >= 8) || m_ticks > 300) { m_timer.stop(); grabAndSave(); }
}

void SceneExport::grabAndSave() {
    QImage img = m_view->grabWindow();
    if (img.isNull() || img.width() < 2) { emit finished(QStringLiteral("Could not render the board")); return; }
    img = img.convertToFormat(QImage::Format_RGB32);
    const bool pdf = m_p.out.endsWith(".pdf", Qt::CaseInsensitive);
    if (pdf) {
        QPdfWriter w(m_p.out);
        w.setResolution(72);
        w.setPageSize(QPageSize(QSizeF(m_p.box.width(), m_p.box.height()), QPageSize::Point));
        w.setPageMargins(QMarginsF(0, 0, 0, 0));
        QPainter p(&w);
        if (!p.isActive()) { emit finished(QStringLiteral("Could not create the PDF")); return; }
        p.setRenderHint(QPainter::SmoothPixmapTransform);
        p.drawImage(QRectF(0, 0, m_p.box.width(), m_p.box.height()), img);
        p.end();
    } else if (!img.save(m_p.out, m_p.out.endsWith(".jpg", Qt::CaseInsensitive) ? "JPG" : "PNG", 95)) {
        emit finished(QStringLiteral("Could not write the image"));
        return;
    }
    emit finished({});
}
