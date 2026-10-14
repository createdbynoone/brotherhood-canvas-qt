#include "jsonfile.h"

#include <QFile>
#include <QSaveFile>

namespace JsonFile {

QJsonObject readObject(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    QJsonParseError err;
    const auto doc = QJsonDocument::fromJson(f.readAll(), &err);
    return err.error == QJsonParseError::NoError && doc.isObject() ? doc.object() : QJsonObject();
}

bool writeObject(const QString &path, const QJsonObject &obj, QJsonDocument::JsonFormat fmt) {
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) return false;
    f.write(QJsonDocument(obj).toJson(fmt));
    return f.commit();
}

}  // namespace JsonFile
