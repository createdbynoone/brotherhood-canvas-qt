#pragma once
#include <QObject>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QStringList>

// Development only (BCQ_DEV builds): plays a small script against the window by posting Qt events straight to it.
// Nothing goes through the operating system, so the test never moves the real pointer or steals focus, and the
// window can stay invisible. See CLAUDE.md for the script syntax.
class Driver : public QObject {
public:
    Driver(QQuickWindow *window, QQmlApplicationEngine *engine, const QString &scriptPath, QObject *parent = nullptr);
    void start();

private:
    void next();
    void run(const QString &line);
    void mouse(QEvent::Type type, double x, double y, Qt::MouseButton button, Qt::KeyboardModifiers mods);
    void key(const QString &name, Qt::KeyboardModifiers mods);
    QPointF nodePoint(const QString &prefix, double fx, double fy);
    QPointF edgePoint(int index, double t);
    void raiseDoubleClick(const QPointF &windowPos);
    void wheelRun(const QStringList &parts);
    Qt::KeyboardModifiers mods(const QStringList &parts, int from) const;

    QQuickWindow *m_window;
    QQmlApplicationEngine *m_engine;
    QStringList m_lines;
    int m_index = 0;
    Qt::MouseButtons m_down;
};
