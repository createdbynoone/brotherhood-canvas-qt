#include "edgemodel.h"

#include "boardmodel.h"

#include <QtMath>

EdgeModel::EdgeModel(BoardModel *board) : QAbstractListModel(board), m_board(board) {}

QHash<int, QByteArray> EdgeModel::roleNames() const {
    return {{IdRole, "edgeId"}, {X1Role, "x1"}, {Y1Role, "y1"}, {X2Role, "x2"}, {Y2Role, "y2"}, {C1XRole, "c1x"}, {C1YRole, "c1y"},
            {C2XRole, "c2x"}, {C2YRole, "c2y"}, {MidXRole, "midX"}, {MidYRole, "midY"}, {LabelRole, "label"}, {ColorRole, "color"},
            {WidthRole, "strokeWidth"}, {DashedRole, "dashed"}, {ArrowRole, "arrow"}, {SelectedRole, "selected"},
            {SrcSideRole, "srcSide"}, {DstSideRole, "dstSide"}, {AngleRole, "endAngle"}, {ArrowStartRole, "arrowStart"}, {StartAngleRole, "startAngle"}, {EndCountRole, "endCount"}, {EndLeadRole, "endLead"}, {StartCountRole, "startCount"}, {StartLeadRole, "startLead"}};
}

QPointF EdgeModel::anchor(const QRectF &r, const QString &side) {
    if (side == "top") return {r.center().x(), r.top()};
    if (side == "bottom") return {r.center().x(), r.bottom()};
    if (side == "left") return {r.left(), r.center().y()};
    return {r.right(), r.center().y()};
}

QPointF EdgeModel::direction(const QString &side) {
    if (side == "top") return {0, -1};
    if (side == "bottom") return {0, 1};
    if (side == "left") return {-1, 0};
    return {1, 0};
}

// Same curvature rule as React Flow's getBezierPath, so existing boards keep their familiar shape.
static double controlOffset(double distance) { return distance >= 0 ? 0.5 * distance : 0.25 * 25 * qSqrt(-distance); }

static QPointF controlFor(const QString &side, const QPointF &a, const QPointF &b) {
    if (side == "left") return {a.x() - controlOffset(a.x() - b.x()), a.y()};
    if (side == "right") return {a.x() + controlOffset(b.x() - a.x()), a.y()};
    if (side == "top") return {a.x(), a.y() - controlOffset(a.y() - b.y())};
    return {a.x(), a.y() + controlOffset(b.y() - a.y())};
}

void EdgeModel::controlPoints(const QPointF &p1, const QString &s1, const QPointF &p2, const QString &s2, QPointF *c1, QPointF *c2) {
    *c1 = controlFor(s1, p1, p2);
    *c2 = controlFor(s2, p2, p1);
}

QPointF EdgeModel::bezier(const QPointF &p1, const QPointF &c1, const QPointF &c2, const QPointF &p2, double t) {
    const double u = 1 - t;
    return p1 * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + p2 * (t * t * t);
}

EdgeModel::Geo EdgeModel::geoFor(const EdgeData &e) const {
    Geo g;
    const int a = m_board->indexOf(e.source), b = m_board->indexOf(e.target);
    if (a < 0 || b < 0) return g;
    g.p1 = anchor(m_board->nodeRect(a), e.sourceHandle);
    g.p2 = anchor(m_board->nodeRect(b), e.targetHandle);
    controlPoints(g.p1, e.sourceHandle, g.p2, e.targetHandle, &g.c1, &g.c2);
    g.mid = bezier(g.p1, g.c1, g.c2, g.p2, 0.5);
    // direction the line is travelling when it reaches the target (for the arrow head)
    QPointF d = g.p2 - g.c2;
    if (d.manhattanLength() < 0.01) d = g.p2 - g.p1;
    g.endAngle = qRadiansToDegrees(qAtan2(d.y(), d.x()));
    QPointF s = g.p1 - g.c1;   // direction the line leaves the source (a head at the start points back along it)
    if (s.manhattanLength() < 0.01) s = g.p1 - g.p2;
    g.startAngle = qRadiansToDegrees(qAtan2(s.y(), s.x()));
    g.ok = true;
    return g;
}

QVariant EdgeModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_edges.size()) return {};
    const EdgeData &e = m_edges[index.row()];
    switch (role) {
    case IdRole: return e.id;
    case LabelRole: return e.label;
    case ColorRole: return e.data.value("color").toString();
    case WidthRole: return e.data.value("strokeWidth").toDouble(1.5);
    case DashedRole: return e.data.value("dashed").toBool(false) || e.data.value("animated").toBool(false);
    case ArrowRole: return e.data.value("arrow").toBool(true);   // heads are on unless switched off
    case ArrowStartRole: return e.data.value("arrowStart").toBool(false);
    case EndCountRole: case EndLeadRole: case StartCountRole: case StartLeadRole: {
        int n = 1; bool lead = true;
        headGroup(index.row(), role == EndCountRole || role == EndLeadRole, &n, &lead);
        return (role == EndCountRole || role == StartCountRole) ? QVariant(n) : QVariant(lead);
    }
    case SelectedRole: return e.id == m_board->selectedEdge();
    case SrcSideRole: return e.sourceHandle;
    case DstSideRole: return e.targetHandle;
    default: break;
    }
    const Geo g = geoFor(e);
    switch (role) {
    case X1Role: return g.p1.x(); case Y1Role: return g.p1.y();
    case X2Role: return g.p2.x(); case Y2Role: return g.p2.y();
    case C1XRole: return g.c1.x(); case C1YRole: return g.c1.y();
    case C2XRole: return g.c2.x(); case C2YRole: return g.c2.y();
    case MidXRole: return g.mid.x(); case MidYRole: return g.mid.y();
    case AngleRole: return g.endAngle;
    case StartAngleRole: return g.startAngle;
    default: return {};
    }
}

void EdgeModel::headGroup(int row, bool atTarget, int *count, bool *lead) const {
    const EdgeData &me = m_edges[row];
    const QString &node = atTarget ? me.target : me.source, &side = atTarget ? me.targetHandle : me.sourceHandle;
    int n = 0; bool first = true;
    for (int i = 0; i < m_edges.size(); ++i) {
        const EdgeData &o = m_edges[i];
        const bool has = atTarget ? o.data.value("arrow").toBool(true) : o.data.value("arrowStart").toBool(false);
        if (!has || (atTarget ? o.target : o.source) != node || (atTarget ? o.targetHandle : o.sourceHandle) != side) continue;
        ++n;
        if (i < row) first = false;
    }
    *count = qMax(1, n); *lead = first;
}

void EdgeModel::refreshHeads() {
    if (m_edges.isEmpty()) return;
    emit dataChanged(index(0), index(m_edges.size() - 1), {ArrowRole, ArrowStartRole, EndCountRole, EndLeadRole, StartCountRole, StartLeadRole});
}

void EdgeModel::reset(const QVector<EdgeData> &e) {
    beginResetModel();
    m_edges = e;
    endResetModel();
}

int EdgeModel::indexOf(const QString &id) const {
    for (int i = 0; i < m_edges.size(); ++i) if (m_edges[i].id == id) return i;
    return -1;
}

void EdgeModel::append(const EdgeData &e) {
    beginInsertRows({}, m_edges.size(), m_edges.size());
    m_edges.append(e);
    endInsertRows();
    refreshHeads();
}

void EdgeModel::removeAt(int row) {
    if (row < 0 || row >= m_edges.size()) return;
    beginRemoveRows({}, row, row);
    m_edges.removeAt(row);
    endRemoveRows();
    refreshHeads();
}

void EdgeModel::removeTouching(const QSet<QString> &ids) {
    for (int i = m_edges.size() - 1; i >= 0; --i)
        if (ids.contains(m_edges[i].source) || ids.contains(m_edges[i].target)) removeAt(i);
}

void EdgeModel::nodesMoved(const QSet<QString> &ids) {
    static const QList<int> geo = {X1Role, Y1Role, X2Role, Y2Role, C1XRole, C1YRole, C2XRole, C2YRole, MidXRole, MidYRole, AngleRole};
    for (int i = 0; i < m_edges.size(); ++i)
        if (ids.contains(m_edges[i].source) || ids.contains(m_edges[i].target)) emit dataChanged(index(i), index(i), geo);
}

void EdgeModel::refreshAll() {
    if (!m_edges.isEmpty()) emit dataChanged(index(0), index(m_edges.size() - 1));
}

void EdgeModel::refreshSelection(const QString &oldId, const QString &newId) {
    for (const QString &id : {oldId, newId}) {
        const int r = id.isEmpty() ? -1 : indexOf(id);
        if (r >= 0) emit dataChanged(index(r), index(r), {SelectedRole});
    }
}

void EdgeModel::setProp(int row, const QString &key, const QVariant &value) {
    if (row < 0 || row >= m_edges.size()) return;
    EdgeData &e = m_edges[row];
    if (key == "label") e.label = value.toString();
    else if (key == "sourceHandle") e.sourceHandle = value.toString();
    else if (key == "targetHandle") e.targetHandle = value.toString();
    else if (!value.isValid() || value.isNull() || (value.typeId() == QMetaType::QString && value.toString().isEmpty())) e.data.remove(key);
    else e.data[key] = QJsonValue::fromVariant(value);
    emit dataChanged(index(row), index(row));
    refreshHeads();
}

bool EdgeModel::exists(const QString &src, const QString &sh, const QString &dst, const QString &dh) const {
    for (const auto &e : m_edges) {
        if (e.source == src && e.target == dst && e.sourceHandle == sh && e.targetHandle == dh) return true;
        if (e.source == dst && e.target == src && e.sourceHandle == dh && e.targetHandle == sh) return true;
    }
    return false;
}

static double distToSegment(const QPointF &p, const QPointF &a, const QPointF &b) {
    const QPointF ab = b - a;
    const double len2 = ab.x() * ab.x() + ab.y() * ab.y();
    double t = len2 < 1e-9 ? 0 : ((p.x() - a.x()) * ab.x() + (p.y() - a.y()) * ab.y()) / len2;
    t = qBound(0.0, t, 1.0);
    const QPointF q = a + ab * t;
    return qHypot(p.x() - q.x(), p.y() - q.y());
}

QString EdgeModel::hitTest(double wx, double wy, double tol) const {
    QString best;
    double bestD = tol;
    const QPointF p(wx, wy);
    for (int i = m_edges.size() - 1; i >= 0; --i) {
        const Geo g = geoFor(m_edges[i]);
        if (!g.ok) continue;
        // cheap reject on the control polygon's bounds
        const QRectF box = QRectF(g.p1, g.p2).normalized().united(QRectF(g.c1, g.c2).normalized()).adjusted(-tol, -tol, tol, tol);
        if (!box.contains(p)) continue;
        QPointF prev = g.p1;
        for (int s = 1; s <= 28; ++s) {
            const QPointF cur = bezier(g.p1, g.c1, g.c2, g.p2, s / 28.0);
            const double d = distToSegment(p, prev, cur);
            if (d < bestD) { bestD = d; best = m_edges[i].id; }
            prev = cur;
        }
    }
    return best;
}
