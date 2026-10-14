#include "driver.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QMimeData>
#include <QElapsedTimer>
#include <QFile>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QQmlContext>
#include <QQmlExpression>
#include <QTextStream>
#include <QTimer>
#include <QWheelEvent>
#include <QtMath>

Driver::Driver(QQuickWindow *window, QQmlApplicationEngine *engine, const QString &scriptPath, QObject *parent)
    : QObject(parent), m_window(window), m_engine(engine) {
    QFile f(scriptPath);
    if (f.open(QIODevice::ReadOnly)) m_lines = QString::fromUtf8(f.readAll()).split('\n');
}

void Driver::start() {
    QFocusEvent focus(QEvent::FocusIn, Qt::ActiveWindowFocusReason);       // the window is never really active: pretend it is
    QCoreApplication::sendEvent(m_window, &focus);
    QTimer::singleShot(0, this, &Driver::next);
}

Qt::KeyboardModifiers Driver::mods(const QStringList &parts, int from) const {
    Qt::KeyboardModifiers m;
    for (int i = from; i < parts.size(); ++i) {
        if (parts[i] == "cmd") m |= Qt::ControlModifier;       // Command is Qt's ControlModifier on macOS
        else if (parts[i] == "shift") m |= Qt::ShiftModifier;
        else if (parts[i] == "alt") m |= Qt::AltModifier;
        else if (parts[i] == "ctrl") m |= Qt::MetaModifier;
    }
    return m;
}

void Driver::mouse(QEvent::Type type, double x, double y, Qt::MouseButton button, Qt::KeyboardModifiers md) {
    if (type == QEvent::MouseButtonPress || type == QEvent::MouseButtonDblClick) m_down |= button;
    if (type == QEvent::MouseButtonRelease) m_down &= ~Qt::MouseButtons(button);
    const QPointF local(x, y);
    QMouseEvent ev(type, local, local, m_window->mapToGlobal(local), button, m_down, md);
    QCoreApplication::sendEvent(m_window, &ev);
}

static int keyCode(const QString &n) {
    static const QHash<QString, int> k = {
        {"esc", Qt::Key_Escape}, {"return", Qt::Key_Return}, {"enter", Qt::Key_Enter}, {"delete", Qt::Key_Backspace}, {"backspace", Qt::Key_Backspace},
        {"space", Qt::Key_Space}, {" ", Qt::Key_Space}, {"left", Qt::Key_Left}, {"right", Qt::Key_Right}, {"up", Qt::Key_Up}, {"down", Qt::Key_Down}, {"tab", Qt::Key_Tab},
        {"[", Qt::Key_BracketLeft}, {"]", Qt::Key_BracketRight}, {"-", Qt::Key_Minus}, {"=", Qt::Key_Equal}, {"+", Qt::Key_Plus}, {"0", Qt::Key_0}};
    if (k.contains(n)) return k[n];
    if (n.size() == 1 && n[0].isLetterOrNumber()) return n[0].toUpper().unicode();
    return 0;
}

void Driver::key(const QString &name, Qt::KeyboardModifiers md) {
    const int code = keyCode(name);
    if (!code) { qWarning("driver: unknown key %s", qPrintable(name)); return; }
    QString text = name.size() == 1 ? name : QString();
    if (md & Qt::ShiftModifier) text = text.toUpper();
    if (md & Qt::ControlModifier) text.clear();
    QKeyEvent down(QEvent::KeyPress, code, md, text), up(QEvent::KeyRelease, code, md, text);
    QCoreApplication::sendEvent(m_window, &down);
    QCoreApplication::sendEvent(m_window, &up);
}

// Window position of a point inside a node: fractions of its rectangle (0..1), found by id prefix.
QPointF Driver::nodePoint(const QString &prefix, double fx, double fy) {
    QObject *root = m_engine->rootObjects().value(0);
    const QString js = QStringLiteral("(function(){ for (const id of board.ids()) if (id.indexOf('%1') === 0) { const r = board.rectOf(id); "
                                      "return [Cam.originX + Cam.sx(r.x + r.width * %2), Cam.originY + Cam.sy(r.y + r.height * %3)] } return null })()")
                           .arg(prefix).arg(fx).arg(fy);
    QQmlExpression e(qmlContext(root), root, js);
    const QVariantList l = e.evaluate().toList();
    if (l.size() != 2) { qWarning("driver: no node starts with %s", qPrintable(prefix)); return {-1, -1}; }
    return {l[0].toDouble(), l[1].toDouble()};
}

// Window position of the point at parameter t (0..1) along an edge's curve; index -1 = the last edge.
QPointF Driver::edgePoint(int index, double t) {
    QObject *root = m_engine->rootObjects().value(0);
    const QString js = QStringLiteral("(function(){ const m = board.edges; let i = %1; if (i < 0) i = m.rowCount() + i; const ix = m.index(i, 0); "
                                      "const d = r => m.data(ix, r); const t = %2, u = 1 - t; "
                                      "const bx = u*u*u*d(258) + 3*u*u*t*d(262) + 3*u*t*t*d(264) + t*t*t*d(260); "
                                      "const by = u*u*u*d(259) + 3*u*u*t*d(263) + 3*u*t*t*d(265) + t*t*t*d(261); "
                                      "return [Cam.originX + Cam.sx(bx), Cam.originY + Cam.sy(by)] })()").arg(index).arg(t);
    QQmlExpression e(qmlContext(root), root, js);
    const QVariantList l = e.evaluate().toList();
    return l.size() == 2 ? QPointF(l[0].toDouble(), l[1].toDouble()) : QPointF(-1, -1);
}

// Qt Quick does not turn a synthetic MouseButtonDblClick into MouseArea.doubleClicked, so the driver raises the
// canvas' own double-click action directly (the press/release before it were delivered normally).
void Driver::raiseDoubleClick(const QPointF &windowPos) {
    QObject *root = m_engine->rootObjects().value(0);
    QQmlExpression e(qmlContext(root), root, QStringLiteral("Cam.doubleClicked(%1 - Cam.originX, %2 - Cam.originY)").arg(windowPos.x()).arg(windowPos.y()));
    e.evaluate();
}

void Driver::run(const QString &raw) {
    const QString line = raw.trimmed();
    if (line.isEmpty() || line.startsWith('#')) return;
    const QStringList p = line.split(' ', Qt::SkipEmptyParts);
    const QString cmd = p[0];
    auto num = [&](int i) { return p.value(i).toDouble(); };
    if (cmd == "move") mouse(QEvent::MouseMove, num(1), num(2), Qt::NoButton, {});
    else if (cmd == "click") {
        const Qt::KeyboardModifiers m = mods(p, 3);
        mouse(QEvent::MouseMove, num(1), num(2), Qt::NoButton, m);
        mouse(QEvent::MouseButtonPress, num(1), num(2), Qt::LeftButton, m);
        mouse(QEvent::MouseButtonRelease, num(1), num(2), Qt::LeftButton, m);
    } else if (cmd == "dclick") {
        mouse(QEvent::MouseMove, num(1), num(2), Qt::NoButton, {});
        mouse(QEvent::MouseButtonPress, num(1), num(2), Qt::LeftButton, {});
        mouse(QEvent::MouseButtonRelease, num(1), num(2), Qt::LeftButton, {});
        raiseDoubleClick(QPointF(num(1), num(2)));
    } else if (cmd == "rclick") {
        mouse(QEvent::MouseMove, num(1), num(2), Qt::NoButton, {});
        mouse(QEvent::MouseButtonPress, num(1), num(2), Qt::RightButton, {});
        mouse(QEvent::MouseButtonRelease, num(1), num(2), Qt::RightButton, {});
    } else if (cmd == "drag" || cmd == "rdrag" || cmd == "mdrag") {
        const Qt::MouseButton b = cmd == "drag" ? Qt::LeftButton : cmd == "rdrag" ? Qt::RightButton : Qt::MiddleButton;
        const Qt::KeyboardModifiers m = mods(p, 5);
        mouse(QEvent::MouseMove, num(1), num(2), Qt::NoButton, m);
        mouse(QEvent::MouseButtonPress, num(1), num(2), b, m);
        const int steps = 20;
        for (int i = 1; i <= steps; ++i) mouse(QEvent::MouseMove, num(1) + (num(3) - num(1)) * i / steps, num(2) + (num(4) - num(2)) * i / steps, b, m);
        mouse(QEvent::MouseButtonRelease, num(3), num(4), b, m);
    } else if (cmd == "wheel") {     // wheel x y dx dy [cmd]  (pixel deltas, like a trackpad)
        const QPointF local(num(1), num(2));
        const QPoint px(int(num(3)), int(num(4)));
        QWheelEvent ev(local, m_window->mapToGlobal(local), px, QPoint(px.x() * 3, px.y() * 3), Qt::NoButton, mods(p, 5), Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(m_window, &ev);
    } else if (cmd == "nclick" || cmd == "ndclick" || cmd == "nrclick") {      // nclick <idprefix> <fx> <fy> [mods]
        const QPointF pt = nodePoint(p.value(1), num(2), num(3));
        const Qt::KeyboardModifiers m = mods(p, 4);
        const Qt::MouseButton b = cmd == "nrclick" ? Qt::RightButton : Qt::LeftButton;
        mouse(QEvent::MouseMove, pt.x(), pt.y(), Qt::NoButton, m);
        mouse(QEvent::MouseButtonPress, pt.x(), pt.y(), b, m);
        mouse(QEvent::MouseButtonRelease, pt.x(), pt.y(), b, m);
        if (cmd == "ndclick") raiseDoubleClick(pt);
    } else if (cmd == "ndrag") {         // ndrag <idprefix> <fx> <fy> <dx px> <dy px> [mods]
        const QPointF a = nodePoint(p.value(1), num(2), num(3));
        const QPointF z = a + QPointF(num(4), num(5));
        const Qt::KeyboardModifiers m = mods(p, 6);
        mouse(QEvent::MouseMove, a.x(), a.y(), Qt::NoButton, m);
        mouse(QEvent::MouseButtonPress, a.x(), a.y(), Qt::LeftButton, m);
        for (int i = 1; i <= 20; ++i) mouse(QEvent::MouseMove, a.x() + (z.x() - a.x()) * i / 20, a.y() + (z.y() - a.y()) * i / 20, Qt::LeftButton, m);
        mouse(QEvent::MouseButtonRelease, z.x(), z.y(), Qt::LeftButton, m);
    } else if (cmd == "eclick" || cmd == "edclick" || cmd == "erclick") {     // eclick <index|-1> <t> [mods]
        const QPointF pt = edgePoint(p.value(1).toInt(), num(2));
        const Qt::KeyboardModifiers m = mods(p, 3);
        const Qt::MouseButton b = cmd == "erclick" ? Qt::RightButton : Qt::LeftButton;
        mouse(QEvent::MouseMove, pt.x(), pt.y(), Qt::NoButton, m);
        mouse(QEvent::MouseButtonPress, pt.x(), pt.y(), b, m);
        mouse(QEvent::MouseButtonRelease, pt.x(), pt.y(), b, m);
        if (cmd == "edclick") raiseDoubleClick(pt);
    } else if (cmd == "key") key(p.value(1), mods(p, 2));
    else if (cmd == "type") { for (const QChar &c : line.mid(5)) key(QString(c).toLower(), c.isUpper() ? Qt::ShiftModifier : Qt::NoModifier); }
    else if (cmd == "shot") {
        const QImage img = m_window->grabWindow();
        img.save(p.value(1));
    } else if (cmd == "eval") {
        QObject *root = m_engine->rootObjects().value(0);
        QQmlExpression e(qmlContext(root), root, line.mid(5));
        bool bad = false;
        const QVariant v = e.evaluate(&bad);
        QTextStream(stdout) << "EVAL " << line.mid(5) << " => " << (bad ? e.error().toString() : v.toString()) << Qt::endl;
    } else if (cmd == "clip") {           // clip image <file> | clip text <text> | clip files <path>...   (system clipboard, for paste tests)
        auto *md = new QMimeData;
        if (p.value(1) == "image") md->setImageData(QImage(p.value(2)));
        else if (p.value(1) == "text") md->setText(line.mid(10));
        else if (p.value(1) == "files") { QList<QUrl> urls; for (int i = 2; i < p.size(); ++i) urls << QUrl::fromLocalFile(p[i]); md->setUrls(urls); }
        QGuiApplication::clipboard()->setMimeData(md);
    } else if (cmd == "quit") QCoreApplication::quit();
    else qWarning("driver: unknown command %s", qPrintable(cmd));
}

void Driver::next() {
    while (m_index < m_lines.size()) {
        const QString line = m_lines[m_index++].trimmed();
        if (line.startsWith("wait ")) { QTimer::singleShot(line.mid(5).toInt(), this, &Driver::next); return; }
        if (line.startsWith("wheelrun ")) { wheelRun(line.split(' ', Qt::SkipEmptyParts)); return; }
        run(line);
        QCoreApplication::processEvents();
    }
    QCoreApplication::quit();
}

// wheelrun <x> <y> <dx> <dy> <ms> [cmd]: a steady stream of wheel events for <ms>, then reports the frame rate achieved
void Driver::wheelRun(const QStringList &p) {
    const double x = p.value(1).toDouble(), y = p.value(2).toDouble();
    const int dx = p.value(3).toInt(), dy = p.value(4).toInt(), ms = p.value(5).toInt();
    const Qt::KeyboardModifiers m = mods(p, 6);
    auto *frames = new int(0);
    auto conn = connect(m_window, &QQuickWindow::frameSwapped, this, [frames] { ++*frames; });
    auto *tick = new QTimer(this);
    auto *clock = new QElapsedTimer;
    clock->start();
    tick->setInterval(16);
    connect(tick, &QTimer::timeout, this, [=] {
        const QPointF local(x, y);
        QWheelEvent ev(local, m_window->mapToGlobal(local), QPoint(dx, dy), QPoint(dx * 3, dy * 3), Qt::NoButton, m, Qt::NoScrollPhase, false);
        QCoreApplication::sendEvent(m_window, &ev);
        if (clock->elapsed() >= ms) {
            tick->stop();
            QObject::disconnect(conn);
            QTextStream(stdout) << "WHEELRUN frames=" << *frames << " in " << clock->elapsed() << " ms => " << (*frames * 1000.0 / clock->elapsed()) << " fps" << Qt::endl;
            delete frames; delete clock; tick->deleteLater();
            QTimer::singleShot(0, this, &Driver::next);
        }
    });
    tick->start();
}
