#include "paths.h"

#include <QDir>
#include <QStandardPaths>

namespace Paths {

static QString ensure(const QString &dir) {
    QDir().mkpath(dir);
    return dir;
}

QString appSupport() {
    const QString o = qEnvironmentVariable("BCQ_DATA_DIR");
    return o.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) : o;
}
QString electronDir() { static const QString d = ensure(appSupport() + "/brotherhood-canvas"); return d; }
QString canvasPrefs() { return electronDir() + "/canvas-prefs.json"; }
QString ownDir() { static const QString d = ensure(appSupport() + "/BrotherhoodCanvasQt"); return d; }
QString ownPrefs() { return ownDir() + "/canvas-qt-prefs.json"; }
QString unlockToken() { return ownDir() + "/unlock.token"; }
QString defaultVault() { return QDir::homePath() + "/Documents/Brotherhood Canvas Vault"; }

}  // namespace Paths
