#include "boarddata.h"

#include <QDateTime>
#include <QRegularExpression>
#include <QUuid>

namespace BoardJson {

QString nowIso() { return QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs); }
QString newId() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }
bool safeId(const QString &id) {
    static const QRegularExpression re("^[A-Za-z0-9-]{1,64}$");
    return re.match(id).hasMatch();
}

NodeData nodeFromJson(const QJsonObject &o) {
    NodeData n;
    n.id = o["id"].toString();
    n.type = o["type"].toString("note");
    const auto pos = o["position"].toObject();
    n.x = pos["x"].toDouble(); n.y = pos["y"].toDouble();
    n.w = o["width"].toDouble(200); n.h = o["height"].toDouble(150);
    n.data = o["data"].toObject();
    n.extra = o;
    for (const char *k : {"id", "type", "position", "width", "height", "data"}) n.extra.remove(QLatin1String(k));
    n.extra.remove("selected"); n.extra.remove("dragging"); n.extra.remove("measured");
    return n;
}

QJsonObject nodeToJson(const NodeData &n) {
    QJsonObject o = n.extra;
    o["id"] = n.id;
    o["type"] = n.type;
    o["position"] = QJsonObject{{"x", n.x}, {"y", n.y}};
    o["data"] = n.data;
    o["width"] = n.w;
    o["height"] = n.h;
    return o;
}

EdgeData edgeFromJson(const QJsonObject &o) {
    EdgeData e;
    e.id = o["id"].toString();
    e.source = o["source"].toString(); e.target = o["target"].toString();
    e.sourceHandle = o["sourceHandle"].toString("right"); e.targetHandle = o["targetHandle"].toString("left");
    e.label = o["label"].toString();
    e.data = o["data"].toObject();
    e.extra = o;
    for (const char *k : {"id", "source", "target", "sourceHandle", "targetHandle", "label", "data"}) e.extra.remove(QLatin1String(k));
    e.extra.remove("selected");
    return e;
}

QJsonObject edgeToJson(const EdgeData &e) {
    QJsonObject o = e.extra;
    o["id"] = e.id;
    o["source"] = e.source; o["target"] = e.target;
    o["sourceHandle"] = e.sourceHandle; o["targetHandle"] = e.targetHandle;
    if (!e.label.isEmpty()) o["label"] = e.label;
    if (!e.data.isEmpty()) o["data"] = e.data;
    return o;
}

BoardData fromJson(const QJsonObject &o) {
    BoardData b;
    b.id = o["id"].toString(); b.name = o["name"].toString("Untitled");
    b.createdAt = o["createdAt"].toString(); b.updatedAt = o["updatedAt"].toString();
    for (const auto &v : o["nodes"].toArray()) b.nodes.append(nodeFromJson(v.toObject()));
    for (const auto &v : o["edges"].toArray()) b.edges.append(edgeFromJson(v.toObject()));
    const auto vp = o["viewport"].toObject();
    b.vx = vp["x"].toDouble(0); b.vy = vp["y"].toDouble(0); b.zoom = vp["zoom"].toDouble(1);
    if (!(b.zoom > 0)) b.zoom = 1;
    b.background = o["background"].toString("dots");
    b.extra = o;
    for (const char *k : {"id", "name", "createdAt", "updatedAt", "nodeCount", "nodes", "edges", "viewport", "background"}) b.extra.remove(QLatin1String(k));
    return b;
}

QJsonObject toJson(const BoardData &b) {
    QJsonObject o = b.extra;
    o["id"] = b.id; o["name"] = b.name; o["createdAt"] = b.createdAt; o["updatedAt"] = b.updatedAt;
    o["nodeCount"] = b.nodes.size();
    QJsonArray ns, es;
    for (const auto &n : b.nodes) ns.append(nodeToJson(n));
    for (const auto &e : b.edges) es.append(edgeToJson(e));
    o["nodes"] = ns; o["edges"] = es;
    o["viewport"] = QJsonObject{{"x", b.vx}, {"y", b.vy}, {"zoom", b.zoom}};
    o["background"] = b.background;
    return o;
}

}  // namespace BoardJson
