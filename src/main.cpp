#include <QCommandLineParser>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>

#include "app/appcontroller.h"
#include "canvas/canvascontroller.h"
#include "canvas/mediaprovider.h"
#include "core/lock.h"
#include "core/prefs.h"
#include "platform/mac.h"
#include "platform/memtrim.h"
#ifdef BCQ_DEV
#include "dev/driver.h"
#endif

int main(int argc, char *argv[]) {
    // Interface scale (Settings > Interface): Qt only reads QT_SCALE_FACTOR at startup, so it is applied here, before
    // the application exists. A value set in the environment (tests) wins.
    // A relaunch from this app inherits the previous run's environment (`open` passes it on), including the
    // QT_SCALE_FACTOR we set ourselves: drop it, or the old scale would beat the one just chosen in Settings.
    if (qEnvironmentVariableIsSet("BCQ_SCALE_APPLIED")) { qunsetenv("QT_SCALE_FACTOR"); qunsetenv("BCQ_SCALE_APPLIED"); }
    const int scalePct = qBound(50, int(Prefs::ownNumber("uiScale", 100)), 100);
    if (!qEnvironmentVariableIsSet("QT_SCALE_FACTOR") && scalePct != 100) qputenv("QT_SCALE_FACTOR", QByteArray::number(scalePct / 100.0));
    qputenv("BCQ_SCALE_APPLIED", QByteArray::number(qEnvironmentVariableIsSet("QT_SCALE_FACTOR") ? int(qEnvironmentVariable("QT_SCALE_FACTOR").toDouble() * 100 + 0.5) : 100));
    const double uiFactor = qEnvironmentVariable("BCQ_SCALE_APPLIED").toInt() / 100.0;
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Brotherhood Canvas");
    QGuiApplication::setOrganizationName("Brotherhood");
    // BCQ_VERSION_OVERRIDE pretends to be an older build so the update flow can be tested against real releases
    QGuiApplication::setApplicationVersion(qEnvironmentVariable("BCQ_VERSION_OVERRIDE", QStringLiteral(APP_VERSION)));
    QQuickStyle::setStyle("Basic");
    Mac::setDarkAppearance();

    // --grab <png>   render the window to a PNG and quit (design review without screen access)
    QCommandLineParser cli;
    QCommandLineOption grab("grab", "Save a screenshot and quit.", "file");
    QCommandLineOption delay("delay", "Milliseconds to wait before the screenshot.", "ms", "1800");
    QCommandLineOption size("size", "Window size WxH.", "WxH", "1480x900");
    QCommandLineOption openOpt("open", "Open a panel at startup (settings | palette | style | export), for design review.", "what");
    QCommandLineOption boardOpt("board", "Open the board whose name contains this text.", "name");
    QCommandLineOption selfTest("selftest", "Run internal checks and exit.");
    QCommandLineOption driveOpt("drive", "Development builds only: play an input script against the window.", "script");
    cli.addOptions({grab, delay, size, openOpt, boardOpt, selfTest, driveOpt});
    cli.process(app);
#ifdef BCQ_DEV
    if (cli.isSet(driveOpt)) Mac::setAccessoryPolicy();
#endif

    if (cli.isSet(selfTest)) {
        const bool ok = AppLock::selfTest();
        qInfo("scrypt RFC 7914 vector: %s", ok ? "ok" : "FAILED");
        return ok ? 0 : 1;
    }

    for (const char *f : {"Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold", "GeistMono-Regular", "GeistMono-Medium",
                          "Phosphor", "Phosphor-Bold", "Phosphor-Fill"})
        QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/%1.ttf").arg(f));
    // Brand font (Sequel 100 Black 75): optional, falls back to Geist Bold
    QString brandFamily;
    const int brandId = QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/Sequel100Black-75.ttf"));
    if (brandId >= 0) brandFamily = QFontDatabase::applicationFontFamilies(brandId).value(0);
    app.setProperty("brandFamily", brandFamily);
    // Marker face for note headings (Niceplan): optional too
    QString markerFamily;
    const int markerId = QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/Niceplan.ttf"));
    if (markerId >= 0) markerFamily = QFontDatabase::applicationFontFamilies(markerId).value(0);
    QGuiApplication::setFont(QFont("Geist", 13));

    AppController appCtl;
    CanvasController canvas;
    QObject::connect(&app, &QGuiApplication::aboutToQuit, &canvas, &CanvasController::flush);

    QQmlApplicationEngine engine;
    engine.addImageProvider("media", new MediaProvider);
    engine.rootContext()->setContextProperty("app", &appCtl);
    engine.rootContext()->setContextProperty("canvas", &canvas);
    engine.rootContext()->setContextProperty("board", canvas.board());
    engine.rootContext()->setContextProperty("grabSize", cli.value(size));
    engine.rootContext()->setContextProperty("sizeForced", cli.isSet(size) || cli.isSet(grab));
    engine.rootContext()->setContextProperty("brandFamily", brandFamily);
    engine.rootContext()->setContextProperty("markerFamily", markerFamily);
    engine.rootContext()->setContextProperty("startOpen", cli.value(openOpt));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Canvas", "Main");

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
    if (!window) return 1;
    QTimer::singleShot(0, [window, &appCtl, uiFactor] {
        Mac::styleWindow(window);
        // QML decides which points of the title bar are empty space (see Main.qml: titleBarHit)
        // AppKit reports points; with a UI scale the QML coordinate space is points / scale
        Mac::installMagnify(window, [&appCtl, uiFactor](double x, double y, double m, int phase) { emit appCtl.magnified(x / uiFactor, y / uiFactor, m, phase); });
        Mac::installTitleBarDrag(window, [window, uiFactor](double x, double y) {
            x /= uiFactor; y /= uiFactor;
            QVariant hit;
            QMetaObject::invokeMethod(window, "titleBarHit", Q_RETURN_ARG(QVariant, hit), Q_ARG(QVariant, x), Q_ARG(QVariant, y));
            return hit.toBool();
        });
    });

    // Gives memory back while the app sits in the background (see memtrim.h). BCQ_TRIM_NOW=1: trim once, 8 s after start (tests)
    auto *memTrim = new MemTrim(&engine, window, [] { MediaProvider::dropCache(); }, &app);
    if (qEnvironmentVariableIntValue("BCQ_TRIM_NOW") > 0) QTimer::singleShot(8000, memTrim, [memTrim] { memTrim->trim(true); });

    canvas.start();
    if (cli.isSet(boardOpt)) {
        const QString q = cli.value(boardOpt);
        for (const auto &m : canvas.boards()->items()) if (m.name.contains(q, Qt::CaseInsensitive)) { canvas.openBoard(m.id); break; }
    }
#ifdef BCQ_DEV
    if (cli.isSet(driveOpt)) {
        window->setOpacity(0);                                   // invisible, never takes the real pointer or focus
        auto *driver = new Driver(window, &engine, cli.value(driveOpt), &app);
        QTimer::singleShot(qEnvironmentVariableIntValue("BCQ_DRIVE_START") > 0 ? qEnvironmentVariableIntValue("BCQ_DRIVE_START") : 2600, driver, &Driver::start);
    }
#endif
    if (!cli.isSet(driveOpt)) appCtl.checkForUpdate();
    auto *recheck = new QTimer(&app);       // a long-running session still hears about new releases
    recheck->setInterval(30 * 60 * 1000);
    QObject::connect(recheck, &QTimer::timeout, &appCtl, &AppController::checkForUpdate);
    recheck->start();

    if (cli.isSet(grab)) {
        const QString out = cli.value(grab);
        QTimer::singleShot(cli.value(delay).toInt(), &app, [window, out, &app] {
            window->grabWindow().save(out);
            app.quit();
        });
    }
    return app.exec();
}
