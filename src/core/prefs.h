#pragma once
#include <QJsonValue>
#include <QString>

// Each accessor reads/writes only its own key and keeps every other key in the file untouched,
// so the Electron build never loses a setting this app doesn't know about.
namespace Prefs {

// canvas-prefs.json (shared with the Electron build)
QString vaultPath();
void setVaultPath(const QString &path);
QString lastBoardId();
void setLastBoardId(const QString &id);
int authFailCount();
double authLockUntil();                    // ms since epoch
void setAuth(int failCount, double lockUntil);

// canvas-qt-prefs.json (this app only)
QJsonValue own(const QString &key);
void setOwn(const QString &key, const QJsonValue &v);
double ownNumber(const QString &key, double fallback);
bool ownBool(const QString &key, bool fallback);
QString ownString(const QString &key, const QString &fallback);

}
