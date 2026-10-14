#include "prefs.h"

#include "jsonfile.h"
#include "paths.h"

#include <QMutex>
#include <QMutexLocker>

namespace Prefs {

static QMutex mtx;

static QJsonValue get(const QString &file, const QString &key) { QMutexLocker l(&mtx); return JsonFile::readObject(file).value(key); }
static void set(const QString &file, const QString &key, const QJsonValue &v) {
    QMutexLocker l(&mtx);
    QJsonObject o = JsonFile::readObject(file);
    o[key] = v;
    JsonFile::writeObject(file, o);
}

QString vaultPath() { return get(Paths::canvasPrefs(), "vaultPath").toString(); }
void setVaultPath(const QString &path) { set(Paths::canvasPrefs(), "vaultPath", path); }
QString lastBoardId() { return get(Paths::canvasPrefs(), "lastBoardId").toString(); }
void setLastBoardId(const QString &id) { set(Paths::canvasPrefs(), "lastBoardId", id); }
int authFailCount() { return get(Paths::canvasPrefs(), "authFailCount").toInt(0); }
double authLockUntil() { return get(Paths::canvasPrefs(), "authLockUntil").toDouble(0); }
void setAuth(int failCount, double lockUntil) {
    QMutexLocker l(&mtx);
    QJsonObject o = JsonFile::readObject(Paths::canvasPrefs());
    o["authFailCount"] = failCount;
    o["authLockUntil"] = lockUntil;
    JsonFile::writeObject(Paths::canvasPrefs(), o);
}

QJsonValue own(const QString &key) { return get(Paths::ownPrefs(), key); }
void setOwn(const QString &key, const QJsonValue &v) { set(Paths::ownPrefs(), key, v); }
double ownNumber(const QString &key, double fallback) { const auto v = own(key); return v.isDouble() ? v.toDouble() : fallback; }
bool ownBool(const QString &key, bool fallback) { const auto v = own(key); return v.isBool() ? v.toBool() : fallback; }
QString ownString(const QString &key, const QString &fallback) { const auto v = own(key); return v.isString() ? v.toString() : fallback; }

}  // namespace Prefs
