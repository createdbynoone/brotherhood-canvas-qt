#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>

class QNetworkAccessManager;

// Window-level state: access key, update notice, interface preferences and small OS helpers.
class AppController : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool unlocked READ unlocked NOTIFY unlockedChanged)
    Q_PROPERTY(double lockUntil READ lockUntil NOTIFY lockChanged)
    Q_PROPERTY(QString version READ version CONSTANT)
    Q_PROPERTY(bool reduceMotion READ reduceMotion CONSTANT)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateChanged)
    Q_PROPERTY(QString updateVersion READ updateVersion NOTIFY updateChanged)
    Q_PROPERTY(QUrl updateUrl READ updateUrl NOTIFY updateChanged)
    Q_PROPERTY(bool checkingUpdate READ checkingUpdate NOTIFY updateChanged)
    Q_PROPERTY(bool updating READ updating NOTIFY updatingChanged)
    Q_PROPERTY(double updateProgress READ updateProgress NOTIFY updatingChanged)       // 0..1
    Q_PROPERTY(QString updateError READ updateError NOTIFY updatingChanged)
    Q_PROPERTY(bool sidebarOpen READ sidebarOpen WRITE setSidebarOpen NOTIFY prefsChanged)
    Q_PROPERTY(bool minimap READ minimap WRITE setMinimap NOTIFY prefsChanged)
    Q_PROPERTY(bool snap READ snap WRITE setSnap NOTIFY prefsChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY prefsChanged)
    Q_PROPERTY(int uiScale READ uiScale WRITE setUiScale NOTIFY uiScaleChanged)        // chosen, percent; applies on relaunch
    Q_PROPERTY(int activeUiScale READ activeUiScale CONSTANT)                         // the scale this run started with

public:
    explicit AppController(QObject *parent = nullptr);

    bool unlocked() const { return m_unlocked; }
    double lockUntil() const;
    QString version() const;
    bool reduceMotion() const { return m_reduceMotion; }
    bool updateAvailable() const { return !m_updateVersion.isEmpty(); }
    QString updateVersion() const { return m_updateVersion; }
    QUrl updateUrl() const { return m_updateUrl; }
    bool checkingUpdate() const { return m_checking; }
    bool updating() const { return m_updating; }
    double updateProgress() const { return m_progress; }
    QString updateError() const { return m_updateError; }
    bool sidebarOpen() const { return m_sidebar; }
    void setSidebarOpen(bool on);
    bool minimap() const { return m_minimap; }
    void setMinimap(bool on);
    bool snap() const { return m_snap; }
    void setSnap(bool on);
    int uiScale() const { return m_uiScale; }
    void setUiScale(int percent);
    int activeUiScale() const { return m_activeUiScale; }
    double volume() const { return m_volume; }
    void setVolume(double v);

    Q_INVOKABLE void verifyKey(const QString &key);      // async; emits keyResult
    Q_INVOKABLE void forgetKey();
    Q_INVOKABLE void dismissUpdate();
    Q_INVOKABLE void checkForUpdate();
    Q_INVOKABLE void restart();             // quit and open the app again (applies the interface scale)
    Q_INVOKABLE void installUpdate();       // download the release zip, replace this app, relaunch
    Q_INVOKABLE void copyText(const QString &text);
    Q_INVOKABLE void openUrl(const QUrl &url);
    Q_INVOKABLE void openPath(const QString &path);
    Q_INVOKABLE void revealFile(const QString &path);
    Q_INVOKABLE void zoomWindow();
    Q_INVOKABLE QString abbreviate(const QString &path) const;       // /Users/me/Desktop -> ~/Desktop
    Q_INVOKABLE QString localPath(const QUrl &url) const { return url.toLocalFile(); }
    Q_INVOKABLE QString formatSize(double bytes) const;
    Q_INVOKABLE QUrl fileUrl(const QString &path) const { return QUrl::fromLocalFile(path); }
    Q_INVOKABLE QVariantList windowGeometry() const;                  // [x, y, w, h] last used, or empty
    Q_INVOKABLE void saveWindowGeometry(int x, int y, int w, int h);

signals:
    void unlockedChanged();
    void lockChanged();
    void updateChanged();
    void updatingChanged();
    void prefsChanged();
    void uiScaleChanged();
    void keyResult(bool ok, double lockUntil);
    void toast(const QString &message, int kind);
    void magnified(double x, double y, double magnification, int phase);   // trackpad pinch, window coordinates

private:
    bool m_unlocked = false, m_reduceMotion = false, m_checking = false, m_updating = false;
    bool m_sidebar = true, m_minimap = true, m_snap = true;
    double m_volume = 1, m_progress = 0;
    int m_uiScale = 100, m_activeUiScale = 100;
    QString m_updateVersion, m_updateError;
    QUrl m_updateUrl, m_updateAsset;
    QNetworkAccessManager *m_nam = nullptr;
};
