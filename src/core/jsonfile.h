#pragma once
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>

// Atomic JSON helpers (QSaveFile). Reads are tolerant: a missing or broken file is an empty object.
namespace JsonFile {
QJsonObject readObject(const QString &path);
bool writeObject(const QString &path, const QJsonObject &obj, QJsonDocument::JsonFormat fmt = QJsonDocument::Indented);
}
