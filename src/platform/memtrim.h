#pragma once
#include <QObject>
#include <QTimer>
#include <functional>

class QQmlEngine;
class QQuickWindow;

// Gives memory back to the OS when nobody is looking. Nothing here discards user data: it only drops what can be
// rebuilt on demand (decoded-image copies, compiled-component caches, freed heap pages, unused scene-graph textures).
//  - the app has been in the background for a while  -> full trim
//  - the app is in use                               -> only a cheap, periodic return of freed heap pages
class MemTrim : public QObject {
public:
    MemTrim(QQmlEngine *engine, QQuickWindow *window, std::function<void()> dropCaches, QObject *parent = nullptr);
    void trim(bool deep);                 // also reachable from tests (see the *_TRIM_NOW variable in main.cpp)

private:
    QQmlEngine *m_engine;
    QQuickWindow *m_window;
    std::function<void()> m_dropCaches;
    QTimer m_idle, m_light;
};
