#include "appcontroller.h"

#include "../core/lock.h"
#include "../core/paths.h"
#include "../core/prefs.h"
#include "../platform/mac.h"

#include <QClipboard>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QGuiApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QWindow>
#include <QtConcurrent>

static const char *kRepo = "createdbynoone/brotherhood-canvas-qt";

AppController::AppController(QObject *parent) : QObject(parent) {
#ifdef BCQ_DEV
    m_unlocked = qEnvironmentVariableIsSet("BCQ_SKIP_LOCK") || AppLock::isRemembered();     // development builds only
#else
    m_unlocked = AppLock::isRemembered();
#endif
    m_reduceMotion = Mac::reduceMotion();
    m_sidebar = Prefs::ownBool("sidebarOpen", true);
    m_minimap = Prefs::ownBool("minimap", true);
    m_snap = Prefs::ownBool("snap", true);
    m_volume = qBound(0.0, Prefs::ownNumber("volume", 1.0), 1.0);
    m_uiScale = qBound(50, int(Prefs::ownNumber("uiScale", 100)), 100);
    m_activeUiScale = qEnvironmentVariableIsSet("BCQ_SCALE_APPLIED") ? qEnvironmentVariableIntValue("BCQ_SCALE_APPLIED") : m_uiScale;
    m_nam = new QNetworkAccessManager(this);
}

QString AppController::version() const { return QCoreApplication::applicationVersion(); }
double AppController::lockUntil() const { return AppLock::lockUntil(); }

void AppController::setSidebarOpen(bool on) { if (on != m_sidebar) { m_sidebar = on; Prefs::setOwn("sidebarOpen", on); emit prefsChanged(); } }
void AppController::setMinimap(bool on) { if (on != m_minimap) { m_minimap = on; Prefs::setOwn("minimap", on); emit prefsChanged(); } }
void AppController::setSnap(bool on) { if (on != m_snap) { m_snap = on; Prefs::setOwn("snap", on); emit prefsChanged(); } }
void AppController::setVolume(double v) { v = qBound(0.0, v, 1.0); if (!qFuzzyCompare(v + 1, m_volume + 1)) { m_volume = v; Prefs::setOwn("volume", v); emit prefsChanged(); } }

void AppController::setUiScale(int percent) {
    percent = qBound(50, percent, 100);
    if (percent == m_uiScale) return;
    m_uiScale = percent;
    Prefs::setOwn("uiScale", percent);
    emit uiScaleChanged();
}

// Qt reads QT_SCALE_FACTOR once, at startup, so a new scale needs a fresh process: wait for this one to exit, reopen.
void AppController::restart() {
    QDir d(QCoreApplication::applicationDirPath());
    d.cdUp(); d.cdUp();
    const QString bundle = d.absolutePath();
    if (bundle.endsWith(".app")) {
        QProcess::startDetached("/bin/sh", {"-c", QStringLiteral("while kill -0 %1 2>/dev/null; do sleep 0.2; done; /usr/bin/open -n \"%2\"")
                                                       .arg(QCoreApplication::applicationPid()).arg(bundle)});
    }
    QCoreApplication::quit();
}

void AppController::verifyKey(const QString &key) {
    if (key.isEmpty()) return;
    (void)QtConcurrent::run([this, key] {
        const bool ok = AppLock::verify(key);       // ~100 ms of PBKDF2: off the GUI thread
        QMetaObject::invokeMethod(this, [this, ok] {
            double until = 0;
            if (ok) { AppLock::clearFailures(); m_unlocked = true; emit unlockedChanged(); }
            else { until = AppLock::registerFailure(); emit lockChanged(); }
            emit keyResult(ok, until);
        }, Qt::QueuedConnection);
    });
}

void AppController::forgetKey() { AppLock::forget(); emit toast(QStringLiteral("The key will be asked again on next launch"), 0); }

// ── Updates ──────────────────────────────────────────────────────────────
static QList<int> versionParts(QString v) {
    v.remove(QRegularExpression("^[vV]"));
    QList<int> out;
    for (const auto &p : v.split('.')) out << p.toInt();
    return out;
}
static bool isNewer(const QString &remote, const QString &local) {
    const auto r = versionParts(remote), l = versionParts(local);
    for (int i = 0; i < qMax(r.size(), l.size()); ++i) {
        const int a = i < r.size() ? r[i] : 0, b = i < l.size() ? l[i] : 0;
        if (a != b) return a > b;
    }
    return false;
}

void AppController::checkForUpdate() {
    m_checking = true; emit updateChanged();
    // BCQ_UPDATE_API lets a test point the check at a local server (see CLAUDE.md); production uses GitHub.
    const QString api = qEnvironmentVariable("BCQ_UPDATE_API", QStringLiteral("https://api.github.com/repos/%1/releases/latest").arg(kRepo));
    QNetworkRequest req{QUrl(api)};
    req.setRawHeader("Accept", "application/vnd.github+json");
    // GitHub answers 403 to requests without a User-Agent, and Qt does not send one by default.
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Brotherhood-Canvas/%1").arg(version()));
    req.setTransferTimeout(8000);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_checking = false;
        if (reply->error() == QNetworkReply::NoError) {
            const auto o = QJsonDocument::fromJson(reply->readAll()).object();
            const QString tag = o["tag_name"].toString();
            if (!tag.isEmpty() && isNewer(tag, version())) {
                m_updateVersion = QString(tag).remove(QRegularExpression("^[vV]"));
                m_updateUrl = QUrl(o["html_url"].toString());
                m_updateAsset = QUrl();
                for (const auto &a : o["assets"].toArray()) {       // Brotherhood-Studio-X.Y.Z-arm64-mac.zip
                    const QString name = a.toObject()["name"].toString();
                    if (name.endsWith("-mac.zip")) { m_updateAsset = QUrl(a.toObject()["browser_download_url"].toString()); break; }
                }
            }
        }
        emit updateChanged();
    });
}

// Downloads the release zip, then hands over to a small script that waits for this process to exit,
// swaps the .app (keeping the old one until the new one is in place), clears quarantine and relaunches.
void AppController::installUpdate() {
    if (m_updating) return;
    // .../Brotherhood Canvas.app/Contents/MacOS -> bundle path
    QDir d(QCoreApplication::applicationDirPath());
    d.cdUp(); d.cdUp();
    const QString bundle = d.absolutePath();
    if (m_updateAsset.isEmpty() || !bundle.endsWith(".app") || !QFileInfo(QFileInfo(bundle).absolutePath()).isWritable()) {
        if (m_updateUrl.isValid()) QDesktopServices::openUrl(m_updateUrl);     // fall back to the release page
        return;
    }
    m_updating = true; m_progress = 0; m_updateError.clear(); emit updatingChanged();

    const QString zip = QDir::tempPath() + "/brotherhood-canvas-update.zip";
    QFile::remove(zip);
    QNetworkRequest req(m_updateAsset);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Brotherhood-Canvas/%1").arg(version()));
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = m_nam->get(req);
    connect(reply, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        if (total > 0) { m_progress = double(got) / double(total); emit updatingChanged(); }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, zip, bundle] {
        reply->deleteLater();
        auto fail = [this](const QString &msg) { m_updating = false; m_updateError = msg; emit updatingChanged(); emit toast(msg, 2); };
        if (reply->error() != QNetworkReply::NoError) { fail(QStringLiteral("Update download failed")); return; }
        QFile f(zip);
        if (!f.open(QIODevice::WriteOnly) || f.write(reply->readAll()) < 1) { fail(QStringLiteral("Could not save the update")); return; }
        f.close();

        const QString script = QDir::tempPath() + "/brotherhood-canvas-update.sh";
        QFile s(script);
        if (!s.open(QIODevice::WriteOnly)) { fail(QStringLiteral("Could not prepare the update")); return; }
        s.write(R"SH(#!/bin/bash
PID="$1"; ZIP="$2"; DEST="$3"
while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
TMP="$(mktemp -d)"
/usr/bin/ditto -x -k "$ZIP" "$TMP" || exit 1
NEW="$(ls -d "$TMP"/*.app | head -1)"
[ -d "$NEW" ] || exit 1
/usr/bin/xattr -cr "$NEW"
rm -rf "$DEST.old"
mv "$DEST" "$DEST.old" || exit 1
if mv "$NEW" "$DEST"; then rm -rf "$DEST.old"; else mv "$DEST.old" "$DEST"; fi
rm -rf "$TMP" "$ZIP"
open "$DEST"
)SH");
        s.close();
        QFile::setPermissions(script, QFile::permissions(script) | QFileDevice::ExeOwner);
        QProcess::startDetached("/bin/bash", {script, QString::number(QCoreApplication::applicationPid()), zip, bundle});
        QCoreApplication::quit();
    });
}

void AppController::dismissUpdate() { m_updateVersion.clear(); m_updateUrl.clear(); emit updateChanged(); }

QVariantList AppController::windowGeometry() const {
    const auto v = Prefs::own("window").toArray();
    if (v.size() != 4 || int(Prefs::ownNumber("windowScale", 100)) != m_activeUiScale) return {};      // saved at another scale: points differ
    return {v[0].toInt(), v[1].toInt(), v[2].toInt(), v[3].toInt()};
}

void AppController::saveWindowGeometry(int x, int y, int w, int h) { Prefs::setOwn("window", QJsonArray{x, y, w, h}); Prefs::setOwn("windowScale", m_activeUiScale); }

// ── OS helpers ───────────────────────────────────────────────────────────
void AppController::copyText(const QString &text) { QGuiApplication::clipboard()->setText(text); }
void AppController::openUrl(const QUrl &url) { QDesktopServices::openUrl(url); }
void AppController::openPath(const QString &path) { QDesktopServices::openUrl(QUrl::fromLocalFile(path)); }
void AppController::revealFile(const QString &path) { Mac::revealInFinder(path); }

void AppController::zoomWindow() {
    const auto windows = QGuiApplication::topLevelWindows();
    if (!windows.isEmpty()) Mac::zoomWindow(windows.first());
}

QString AppController::abbreviate(const QString &path) const {
    const QString home = QDir::homePath();
    return path.startsWith(home) ? "~" + path.mid(home.size()) : path;
}

QString AppController::formatSize(double bytes) const {
    if (bytes < 1024) return QStringLiteral("%1 B").arg(qint64(bytes));
    if (bytes < 1024 * 1024) return QStringLiteral("%1 KB").arg(bytes / 1024, 0, 'f', 1);
    if (bytes < 1024.0 * 1024 * 1024) return QStringLiteral("%1 MB").arg(bytes / 1024 / 1024, 0, 'f', 1);
    return QStringLiteral("%1 GB").arg(bytes / 1024 / 1024 / 1024, 0, 'f', 2);
}
