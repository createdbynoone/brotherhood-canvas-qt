#pragma once
#include <QJsonArray>
#include <QJsonObject>
#include <QString>
#include <QVector>

// Plain data for one board, mirroring the SerializedBoard JSON the Electron build writes. Anything this app does
// not model (unknown keys at node, data or board level) rides along in the `extra` / `data` objects and is written
// back untouched, so a board edited here still opens cleanly in the other build.
struct NodeData {
    QString id;
    QString type;                 // image | video | pdf | text | note | title | file
    double x = 0, y = 0, w = 200, h = 150;
    QJsonObject data;             // content, label, locked, filePath, fileName, mimeType, fileSize, thumbnailPath,
                                  // noteColor, fontSize, nodeStyle{backgroundColor,borderColor,borderWidth,borderRadius,opacity}
    QJsonObject extra;            // other top-level node keys
};

struct EdgeData {
    QString id, source, target, sourceHandle, targetHandle, label;
    QJsonObject data;             // color, strokeWidth, animated, dashed, arrow
    QJsonObject extra;
};

struct BoardData {
    QString id, name, createdAt, updatedAt;
    QVector<NodeData> nodes;      // array order is the stacking order (last = on top)
    QVector<EdgeData> edges;
    double vx = 0, vy = 0, zoom = 1;
    QString background = "dots";  // dots | lines | cross | none
    QJsonObject extra;
};

namespace BoardJson {
BoardData fromJson(const QJsonObject &o);
QJsonObject toJson(const BoardData &b);        // refreshes nodeCount, keeps updatedAt as given
NodeData nodeFromJson(const QJsonObject &o);
QJsonObject nodeToJson(const NodeData &n);
EdgeData edgeFromJson(const QJsonObject &o);
QJsonObject edgeToJson(const EdgeData &e);
QString nowIso();                              // 2026-10-14T06:48:32.176Z
QString newId();                               // UUID without braces
bool safeId(const QString &id);                // ^[A-Za-z0-9-]{1,64}$
}
