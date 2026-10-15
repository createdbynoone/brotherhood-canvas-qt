#include "memtrim.h"

#include <QGuiApplication>
#include <QPixmapCache>
#include <QQmlEngine>
#include <QQuickWindow>
#include <malloc/malloc.h>

MemTrim::MemTrim(QQmlEngine *engine, QQuickWindow *window, std::function<void()> dropCaches, QObject *parent)
    : QObject(parent), m_engine(engine), m_window(window), m_dropCaches(std::move(dropCaches)) {
    m_idle.setSingleShot(true);
    m_idle.setInterval(45 * 1000);
    connect(&m_idle, &QTimer::timeout, this, [this] { trim(true); });
    connect(qApp, &QGuiApplication::applicationStateChanged, this, [this](Qt::ApplicationState s) {
        if (s == Qt::ApplicationActive) m_idle.stop(); else m_idle.start();
    });
    m_light.setInterval(3 * 60 * 1000);
    connect(&m_light, &QTimer::timeout, this, [this] { trim(false); });
    m_light.start();
}

void MemTrim::trim(bool deep) {
    if (deep) {
        if (m_dropCaches) m_dropCaches();
        QPixmapCache::clear();
        if (m_engine) { m_engine->trimComponentCache(); m_engine->collectGarbage(); }
        if (m_window) m_window->releaseResources();
    }
    malloc_zone_pressure_relief(nullptr, 0);     // hand freed pages back to the system
}
