#include "boardmodel.h"

#include "edgemodel.h"

#include <QDir>
#include <QtMath>
#include <algorithm>

static const char *kAccentHex = "#F54F1B";

BoardModel::BoardModel(QObject *parent) : QAbstractListModel(parent) {
    m_edges = new EdgeModel(this);
    m_visNodes = new CullProxy(this, nullptr, this);
    m_visEdges = new CullProxy(this, m_edges, this);
}

void BoardModel::setCull(double l, double t, double r, double b) {
    const QRectF rect(QPointF(l, t), QPointF(r, b));
    m_visNodes->setRect(rect);
    m_visEdges->setRect(rect);
}

QHash<int, QByteArray> BoardModel::roleNames() const {
    return {{IdRole, "nodeId"}, {TypeRole, "nodeType"}, {XRole, "posX"}, {YRole, "posY"}, {WRole, "boxW"}, {HRole, "boxH"},
            {SelectedRole, "selected"}, {ContentRole, "content"}, {LabelRole, "label"}, {LockedRole, "locked"},
            {FilePathRole, "filePath"}, {FileAbsRole, "fileAbs"}, {FileNameRole, "fileName"}, {FileSizeRole, "fileSize"},
            {ThumbPathRole, "thumbPath"}, {NoteColorRole, "noteColor"}, {FontSizeRole, "fontSize"}, {StyleBgRole, "sBg"},
            {StyleBorderRole, "sBorder"}, {StyleBorderWRole, "sBorderW"}, {StyleRadiusRole, "sRadius"},
            {StyleOpacityRole, "sOpacity"}, {HasStyleRole, "hasStyle"}, {EditingRole, "editing"}};
}

QVariant BoardModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_nodes.size()) return {};
    const NodeData &n = m_nodes[index.row()];
    const QJsonObject st = n.data.value("nodeStyle").toObject();
    switch (role) {
    case IdRole: return n.id;
    case TypeRole: return n.type;
    case XRole: return n.x;
    case YRole: return n.y;
    case WRole: return n.w;
    case HRole: return n.h;
    case SelectedRole: return m_selected.contains(n.id);
    case ContentRole: return n.data.value("content").toString();
    case LabelRole: return n.data.value("label").toString();
    case LockedRole: return n.data.value("locked").toBool(false);
    case FilePathRole: return n.data.value("filePath").toString();
    case FileAbsRole: {
        const QString rel = n.data.value("filePath").toString();
        if (rel.isEmpty() || m_vaultRoot.isEmpty()) return QString();
        const QString root = QDir(m_vaultRoot).canonicalPath(), abs = QDir::cleanPath(root + "/" + rel);
        return abs.startsWith(root + "/") ? abs : QString();
    }
    case FileNameRole: return n.data.value("fileName").toString();
    case FileSizeRole: return n.data.value("fileSize").toDouble(0);
    case ThumbPathRole: return n.data.value("thumbnailPath").toString();
    case NoteColorRole: return n.data.value("noteColor").toString(kAccentHex);
    case FontSizeRole: return n.data.value("fontSize").toInt(32);
    case StyleBgRole: return st.value("backgroundColor").toString();
    case StyleBorderRole: return st.value("borderColor").toString();
    case StyleBorderWRole: return st.value("borderWidth").toDouble(-1);
    case StyleRadiusRole: return st.value("borderRadius").toDouble(-1);
    case StyleOpacityRole: return st.value("opacity").toDouble(-1);
    case HasStyleRole: return !st.isEmpty();
    case EditingRole: return n.id == m_editing;
    default: return {};
    }
}

// ── Lifecycle ────────────────────────────────────────────────────────────

void BoardModel::rebuildIndex() {
    m_index.clear();
    for (int i = 0; i < m_nodes.size(); ++i) m_index.insert(m_nodes[i].id, i);
}

void BoardModel::load(const BoardData &b) {
    beginResetModel();
    m_nodes = b.nodes;
    rebuildIndex();
    m_selected.clear(); m_selectedEdge.clear(); m_editing.clear(); m_labelEdit.clear(); m_guides.clear();
    m_undo.clear(); m_redo.clear(); m_gesture = m_gestureSnapped = false;
    m_id = b.id; m_name = b.name; m_createdAt = b.createdAt; m_updatedAt = b.updatedAt; m_contentDirty = false; m_background = b.background; m_extra = b.extra;
    m_vx = b.vx; m_vy = b.vy; m_zoom = b.zoom;
    m_edges->reset(b.edges);
    endResetModel();
    emit boardChanged(); emit backgroundChanged(); emit countChanged(); emit selectionChanged(); emit historyChanged();
    emit boundsChanged(); emit viewportLoaded(); emit editingChanged(); emit guidesChanged();
}

void BoardModel::clear() { load(BoardData()); }

BoardData BoardModel::toBoardData() {
    BoardData b;
    if (m_contentDirty || m_updatedAt.isEmpty()) { m_updatedAt = BoardJson::nowIso(); m_contentDirty = false; }
    b.id = m_id; b.name = m_name; b.createdAt = m_createdAt; b.updatedAt = m_updatedAt;
    b.nodes = m_nodes; b.edges = m_edges->edges();
    b.vx = m_vx; b.vy = m_vy; b.zoom = m_zoom; b.background = m_background; b.extra = m_extra;
    return b;
}

void BoardModel::setBackground(const QString &b) {
    if (b == m_background) return;
    m_background = b;
    emit backgroundChanged();
    m_contentDirty = true;
    emit modified();
}

void BoardModel::setViewport(double x, double y, double z) {
    m_vx = x; m_vy = y; m_zoom = z;
    emit viewportModified();
}

QString BoardModel::selectedType() const {
    const int r = m_selected.size() == 1 ? indexOf(*m_selected.begin()) : -1;
    return r >= 0 ? m_nodes[r].type : QString();
}

bool BoardModel::hasSelectionLocked() const {
    for (const auto &id : m_selected) { const int r = indexOf(id); if (r >= 0 && lockedRow(r)) return true; }
    return false;
}

QRectF BoardModel::bounds() const {
    QRectF u;
    for (const auto &n : m_nodes) u = u.isNull() ? QRectF(n.x, n.y, n.w, n.h) : u.united(QRectF(n.x, n.y, n.w, n.h));
    return u;
}

QRectF BoardModel::rectOf(const QString &id) const { const int r = indexOf(id); return r < 0 ? QRectF() : nodeRect(r); }

QRectF BoardModel::selectionRect() const {
    QRectF u;
    for (const auto &id : m_selected) { const int r = indexOf(id); if (r >= 0) u = u.isNull() ? nodeRect(r) : u.united(nodeRect(r)); }
    return u;
}

QStringList BoardModel::selectedIds() const {
    QStringList out;           // in stacking order
    for (const auto &n : m_nodes) if (m_selected.contains(n.id)) out << n.id;
    return out;
}

QStringList BoardModel::ids() const {
    QStringList out;
    for (const auto &n : m_nodes) out << n.id;
    return out;
}

QVector<NodeData> BoardModel::selectedNodes() const {
    QVector<NodeData> out;
    for (const auto &n : m_nodes) if (m_selected.contains(n.id)) out.append(n);
    return out;
}

QString BoardModel::filePathOf(const QString &id) const {
    const int r = indexOf(id);
    return r < 0 ? QString() : data(index(r), FileAbsRole).toString();
}

QVariantMap BoardModel::nodeInfo(const QString &id) const {
    const int r = indexOf(id);
    if (r < 0) return {};
    const NodeData &n = m_nodes[r];
    return {{"id", n.id}, {"type", n.type}, {"x", n.x}, {"y", n.y}, {"w", n.w}, {"h", n.h},
            {"label", n.data.value("label").toString()}, {"content", n.data.value("content").toString()},
            {"locked", n.data.value("locked").toBool()}, {"fileName", n.data.value("fileName").toString()},
            {"filePath", n.data.value("filePath").toString()}, {"noteColor", n.data.value("noteColor").toString(kAccentHex)},
            {"fontSize", n.data.value("fontSize").toInt(32)}, {"hasStyle", !n.data.value("nodeStyle").toObject().isEmpty()},
            {"sBg", n.data.value("nodeStyle").toObject().value("backgroundColor").toString()},
            {"sBorder", n.data.value("nodeStyle").toObject().value("borderColor").toString()},
            {"sBorderW", n.data.value("nodeStyle").toObject().value("borderWidth").toDouble(-1)},
            {"sRadius", n.data.value("nodeStyle").toObject().value("borderRadius").toDouble(-1)},
            {"sOpacity", n.data.value("nodeStyle").toObject().value("opacity").toDouble(-1)}};
}

QVariantList BoardModel::search(const QString &query, int limit) const {
    QVariantList out;
    const QString q = query.trimmed();
    if (q.isEmpty()) return out;
    for (int i = m_nodes.size() - 1; i >= 0 && out.size() < limit; --i) {
        const NodeData &n = m_nodes[i];
        const QString content = n.data.value("content").toString(), label = n.data.value("label").toString(), file = n.data.value("fileName").toString();
        if (!content.contains(q, Qt::CaseInsensitive) && !label.contains(q, Qt::CaseInsensitive) && !file.contains(q, Qt::CaseInsensitive)) continue;
        QString title = !label.isEmpty() ? label : !content.isEmpty() ? content.section('\n', 0, 0).remove(QRegularExpression("^#+\\s*")) : file;
        if (title.size() > 60) title = title.left(58) + "…";
        out.append(QVariantMap{{"id", n.id}, {"title", title.isEmpty() ? n.type : title}, {"type", n.type}});
    }
    return out;
}

// ── History ──────────────────────────────────────────────────────────────

void BoardModel::snapshot() {
    if (m_gesture) {
        if (m_gestureSnapped) return;
        m_gestureSnapped = true;
    }
    m_undo.append({m_nodes, m_edges->edges()});
    if (m_undo.size() > 80) m_undo.removeFirst();
    m_redo.clear();
    emit historyChanged();
}

void BoardModel::beginGesture() { m_gesture = true; m_gestureSnapped = false; }
void BoardModel::endGesture() { m_gesture = false; m_gestureSnapped = false; }

void BoardModel::restore(const Snap &s) {
    beginResetModel();
    m_nodes = s.nodes;
    rebuildIndex();
    m_edges->reset(s.edges);
    endResetModel();
    QSet<QString> keep;
    for (const auto &id : m_selected) if (m_index.contains(id)) keep.insert(id);
    m_selected = keep;
    if (m_edges->indexOf(m_selectedEdge) < 0) m_selectedEdge.clear();
    if (!m_index.contains(m_editing)) m_editing.clear();
    emit countChanged(); emit selectionChanged(); emit boundsChanged(); emit editingChanged();
    changed();
}

void BoardModel::undo() {
    if (m_undo.isEmpty()) return;
    m_redo.append({m_nodes, m_edges->edges()});
    const Snap s = m_undo.takeLast();
    restore(s);
    emit historyChanged();
}

void BoardModel::redo() {
    if (m_redo.isEmpty()) return;
    m_undo.append({m_nodes, m_edges->edges()});
    const Snap s = m_redo.takeLast();
    restore(s);
    emit historyChanged();
}

void BoardModel::changed() {
    m_contentDirty = true;
    refilter();
    emit boundsChanged();
    emit modified();
}

void BoardModel::emitRow(int row, const QList<int> &roles) { emit dataChanged(index(row), index(row), roles); }
void BoardModel::emitGeometry(const QSet<QString> &ids) { m_edges->nodesMoved(ids); refilter(); }

// ── Selection ────────────────────────────────────────────────────────────

void BoardModel::setSelection(const QSet<QString> &ids, const QString &edge) {
    if (ids == m_selected && edge == m_selectedEdge) return;
    const QSet<QString> before = m_selected;
    const QString oldEdge = m_selectedEdge;
    m_selected = ids;
    m_selectedEdge = edge;
    for (const auto &id : before) if (!ids.contains(id)) { const int r = indexOf(id); if (r >= 0) emitRow(r, {SelectedRole}); }
    for (const auto &id : ids) if (!before.contains(id)) { const int r = indexOf(id); if (r >= 0) emitRow(r, {SelectedRole}); }
    if (oldEdge != edge) m_edges->refreshSelection(oldEdge, edge);
    refilter();
    emit selectionChanged();
    emit boundsChanged();
}

void BoardModel::selectOnly(const QString &id) { setSelection(m_index.contains(id) ? QSet<QString>{id} : QSet<QString>()); }
void BoardModel::toggleSelected(const QString &id) {
    if (!m_index.contains(id)) return;
    QSet<QString> s = m_selected;
    if (!s.remove(id)) s.insert(id);
    setSelection(s);
}
void BoardModel::selectAll() {
    QSet<QString> s;
    for (const auto &n : m_nodes) s.insert(n.id);
    setSelection(s);
}
void BoardModel::clearSelection() { setSelection({}); }
void BoardModel::selectEdge(const QString &id) { setSelection({}, id); }
void BoardModel::selectIds(const QStringList &ids) {
    QSet<QString> s;
    for (const auto &id : ids) if (m_index.contains(id)) s.insert(id);
    setSelection(s);
}

void BoardModel::setEditingId(const QString &id) {
    if (id == m_editing) return;
    const QString old = m_editing;
    m_editing = id;
    for (const auto &x : {old, id}) { const int r = x.isEmpty() ? -1 : indexOf(x); if (r >= 0) emitRow(r, {EditingRole}); }
    refilter();
    emit editingChanged();
}
void BoardModel::setLabelEditId(const QString &id) { if (id != m_labelEdit) { m_labelEdit = id; emit editingChanged(); } }

void BoardModel::beginMarquee(bool additive) { m_marqueeBase = additive ? m_selected : QSet<QString>(); }

void BoardModel::marquee(double x0, double y0, double x1, double y1) {
    const QRectF box = QRectF(QPointF(x0, y0), QPointF(x1, y1)).normalized();
    QSet<QString> s = m_marqueeBase;
    for (const auto &n : m_nodes) if (box.intersects(QRectF(n.x, n.y, n.w, n.h))) s.insert(n.id);
    setSelection(s);
}

// ── Hit testing ──────────────────────────────────────────────────────────

static QPointF resizeHandlePoint(const QRectF &r, int i) {
    switch (i) {
    case 0: return r.topLeft();
    case 1: return {r.center().x(), r.top()};
    case 2: return r.topRight();
    case 3: return {r.right(), r.center().y()};
    case 4: return r.bottomRight();
    case 5: return {r.center().x(), r.bottom()};
    case 6: return r.bottomLeft();
    default: return {r.left(), r.center().y()};
    }
}

QVariantMap BoardModel::hit(double wx, double wy, double zoom) const {
    const double t = 1.0 / qMax(zoom, 0.01);
    const QPointF p(wx, wy);
    const QString single = m_selected.size() == 1 ? *m_selected.begin() : QString();
    // 1. corner grips of the selected node
    if (!single.isEmpty()) {
        const int r = indexOf(single);
        if (r >= 0 && !lockedRow(r)) {
            const QRectF rc = nodeRect(r);
            const double tol = 8 * t;
            for (int i : {0, 2, 4, 6}) {
                const QPointF h = resizeHandlePoint(rc, i);
                if (qAbs(wx - h.x()) <= tol && qAbs(wy - h.y()) <= tol) return {{"kind", "resize"}, {"id", single}, {"handle", i}};
            }
        }
    }
    // 2. connection handles, resize edges and node bodies, topmost first
    static const char *sides[] = {"top", "right", "bottom", "left"};
    for (int i = m_nodes.size() - 1; i >= 0; --i) {
        const QRectF rc = nodeRect(i);
        if (!rc.adjusted(-16 * t, -16 * t, 16 * t, 16 * t).contains(p)) continue;
        for (const char *s : sides) {
            const QPointF a = EdgeModel::anchor(rc, QLatin1String(s));
            if (qHypot(wx - a.x(), wy - a.y()) <= 12 * t) return {{"kind", "handle"}, {"id", m_nodes[i].id}, {"side", QString::fromLatin1(s)}};
        }
        if (m_nodes[i].id == single && !lockedRow(i)) {       // the border of the selected node is a resize edge
            const double e = 5 * t;
            const bool inX = wx > rc.left() + 8 * t && wx < rc.right() - 8 * t, inY = wy > rc.top() + 8 * t && wy < rc.bottom() - 8 * t;
            if (inX && qAbs(wy - rc.top()) <= e) return {{"kind", "resize"}, {"id", single}, {"handle", 1}};
            if (inX && qAbs(wy - rc.bottom()) <= e) return {{"kind", "resize"}, {"id", single}, {"handle", 5}};
            if (inY && qAbs(wx - rc.left()) <= e) return {{"kind", "resize"}, {"id", single}, {"handle", 7}};
            if (inY && qAbs(wx - rc.right()) <= e) return {{"kind", "resize"}, {"id", single}, {"handle", 3}};
        }
        if (rc.contains(p)) return {{"kind", "node"}, {"id", m_nodes[i].id}, {"type", m_nodes[i].type}};
    }
    // 3. connections
    const QString e = m_edges->hitTest(wx, wy, 7 * t);
    if (!e.isEmpty()) return {{"kind", "edge"}, {"id", e}};
    return {{"kind", "none"}};
}

// ── Move ─────────────────────────────────────────────────────────────────

void BoardModel::beginMove(const QString &id) {
    if (!m_selected.contains(id)) selectOnly(id);
    m_moveOrigins.clear();
    m_moved = false;
    for (const auto &sid : m_selected) {
        const int r = indexOf(sid);
        if (r >= 0 && !lockedRow(r)) m_moveOrigins.append({sid, m_nodes[r].x, m_nodes[r].y});
    }
}

void BoardModel::moveBy(double dx, double dy, double zoom, bool snap) {
    if (m_moveOrigins.isEmpty()) return;
    if (!m_moved) {
        if (qAbs(dx) + qAbs(dy) < 0.01) return;
        snapshot();
        m_moved = true;
    }
    QSet<QString> movingIds;
    QRectF box;
    for (const auto &o : m_moveOrigins) {
        movingIds.insert(o.id);
        const int r = indexOf(o.id);
        const QRectF rc(o.x, o.y, m_nodes[r].w, m_nodes[r].h);
        box = box.isNull() ? rc : box.united(rc);
    }
    double ax = dx, ay = dy;
    QVariantList guides;
    if (snap && m_snap) {
        const double thr = 8.0 / qMax(zoom, 0.01);
        QRectF mv = box.translated(dx, dy);
        const double mx[3] = {mv.left(), mv.center().x(), mv.right()}, my[3] = {mv.top(), mv.center().y(), mv.bottom()};
        double bestX = thr + 1, bestY = thr + 1;
        for (const auto &n : m_nodes) {
            if (movingIds.contains(n.id)) continue;
            const double ox[3] = {n.x, n.x + n.w / 2, n.x + n.w}, oy[3] = {n.y, n.y + n.h / 2, n.y + n.h};
            for (int a = 0; a < 3; ++a) for (int b = 0; b < 3; ++b) {
                const double ddx = ox[a] - mx[b], ddy = oy[a] - my[b];
                if (qAbs(ddx) <= thr && qAbs(ddx) < qAbs(bestX)) bestX = ddx;
                if (qAbs(ddy) <= thr && qAbs(ddy) < qAbs(bestY)) bestY = ddy;
            }
        }
        if (qAbs(bestX) <= thr) ax += bestX;
        if (qAbs(bestY) <= thr) ay += bestY;
        mv = box.translated(ax, ay);
        const double fx[3] = {mv.left(), mv.center().x(), mv.right()}, fy[3] = {mv.top(), mv.center().y(), mv.bottom()};
        for (int b = 0; b < 3; ++b) {      // vertical guides (equal x)
            double lo = mv.top(), hi = mv.bottom(); bool any = false;
            for (const auto &n : m_nodes) {
                if (movingIds.contains(n.id)) continue;
                const double ox[3] = {n.x, n.x + n.w / 2, n.x + n.w};
                for (int a = 0; a < 3; ++a) if (qAbs(ox[a] - fx[b]) < 0.5) { any = true; lo = qMin(lo, n.y); hi = qMax(hi, n.y + n.h); break; }
            }
            if (any) guides.append(QVariantMap{{"x1", fx[b]}, {"y1", lo}, {"x2", fx[b]}, {"y2", hi}});
        }
        for (int b = 0; b < 3; ++b) {      // horizontal guides (equal y)
            double lo = mv.left(), hi = mv.right(); bool any = false;
            for (const auto &n : m_nodes) {
                if (movingIds.contains(n.id)) continue;
                const double oy[3] = {n.y, n.y + n.h / 2, n.y + n.h};
                for (int a = 0; a < 3; ++a) if (qAbs(oy[a] - fy[b]) < 0.5) { any = true; lo = qMin(lo, n.x); hi = qMax(hi, n.x + n.w); break; }
            }
            if (any) guides.append(QVariantMap{{"x1", lo}, {"y1", fy[b]}, {"x2", hi}, {"y2", fy[b]}});
        }
    }
    for (const auto &o : m_moveOrigins) {
        const int r = indexOf(o.id);
        m_nodes[r].x = o.x + ax;
        m_nodes[r].y = o.y + ay;
        emitRow(r, {XRole, YRole});
    }
    emitGeometry(movingIds);
    if (guides != m_guides || !m_guides.isEmpty()) { m_guides = guides; emit guidesChanged(); }
    emit boundsChanged();
}

void BoardModel::endMove() {
    const bool moved = m_moved;
    m_moveOrigins.clear();
    m_moved = false;
    if (!m_guides.isEmpty()) { m_guides.clear(); emit guidesChanged(); }
    if (moved) changed();
}

// ── Resize ───────────────────────────────────────────────────────────────

QSizeF BoardModel::minSize(const QString &type) const {
    if (type == "note") return {140, 100};
    if (type == "pdf") return {140, 160};
    if (type == "title") return {120, 36};
    if (type == "video") return {120, 80};
    if (type == "text") return {120, 80};
    return {100, 80};
}

QSizeF BoardModel::defaultSize(const QString &type) {
    if (type == "text") return {260, 180};
    if (type == "note") return {220, 180};
    if (type == "title") return {400, 80};
    if (type == "image") return {240, 200};
    if (type == "video") return {280, 200};
    if (type == "pdf") return {200, 220};
    return {200, 160};
}

void BoardModel::beginResize(const QString &id, int handle) {
    const int r = indexOf(id);
    if (r < 0 || lockedRow(r)) return;
    m_resizeId = id; m_resizeHandle = handle; m_resizeStart = nodeRect(r); m_resized = false;
}

void BoardModel::resizeBy(double dx, double dy, bool freeAspect) {
    const int row = indexOf(m_resizeId);
    if (row < 0 || m_resizeHandle < 0) return;
    if (!m_resized) {
        if (qAbs(dx) + qAbs(dy) < 0.01) return;
        snapshot();
        m_resized = true;
    }
    const NodeData &n = m_nodes[row];
    const QSizeF mn = minSize(n.type);
    const QRectF s = m_resizeStart;
    double l = s.left(), t = s.top(), r = s.right(), b = s.bottom();
    const int h = m_resizeHandle;
    const bool movesL = h == 0 || h == 6 || h == 7, movesR = h == 2 || h == 3 || h == 4, movesT = h == 0 || h == 1 || h == 2, movesB = h == 4 || h == 5 || h == 6;
    if (movesL) l += dx;
    if (movesR) r += dx;
    if (movesT) t += dy;
    if (movesB) b += dy;
    const bool corner = h == 0 || h == 2 || h == 4 || h == 6;
    const bool media = n.type == "image" || n.type == "video";
    if (corner && media && !freeAspect && s.width() > 1 && s.height() > 1) {
        double k = qMax((r - l) / s.width(), (b - t) / s.height());
        k = qMax(k, qMax(mn.width() / s.width(), mn.height() / s.height()));
        const double w = s.width() * k, hh = s.height() * k;
        if (movesL) l = s.right() - w; else r = s.left() + w;
        if (movesT) t = s.bottom() - hh; else b = s.top() + hh;
    } else {
        if (r - l < mn.width()) { if (movesL) l = r - mn.width(); else r = l + mn.width(); }
        if (b - t < mn.height()) { if (movesT) t = b - mn.height(); else b = t + mn.height(); }
    }
    m_nodes[row].x = l; m_nodes[row].y = t; m_nodes[row].w = r - l; m_nodes[row].h = b - t;
    emitRow(row, {XRole, YRole, WRole, HRole});
    emitGeometry({m_resizeId});
    emit boundsChanged();
}

void BoardModel::endResize() {
    const bool did = m_resized;
    m_resizeId.clear(); m_resizeHandle = -1; m_resized = false;
    if (did) changed();
}

// ── Editing ──────────────────────────────────────────────────────────────

QString BoardModel::addNode(const QString &type, double x, double y, double w, double h) {
    snapshot();
    NodeData n;
    n.id = BoardJson::newId(); n.type = type;
    const QSizeF d = defaultSize(type);
    n.w = w > 0 ? w : d.width(); n.h = h > 0 ? h : d.height();
    n.x = x - n.w / 2; n.y = y - n.h / 2;       // centred on the given point
    n.data["content"] = "";
    if (type == "note") n.data["noteColor"] = kAccentHex;
    if (type == "title") n.data["fontSize"] = 32;
    beginInsertRows({}, m_nodes.size(), m_nodes.size());
    m_nodes.append(n);
    m_index.insert(n.id, m_nodes.size() - 1);
    endInsertRows();
    emit countChanged();
    setSelection({n.id});
    changed();
    return n.id;
}

void BoardModel::insertNodes(const QVector<NodeData> &nodes, bool select) {
    if (nodes.isEmpty()) return;
    snapshot();
    beginInsertRows({}, m_nodes.size(), m_nodes.size() + nodes.size() - 1);
    QSet<QString> ids;
    for (const auto &n : nodes) { m_nodes.append(n); m_index.insert(n.id, m_nodes.size() - 1); ids.insert(n.id); }
    endInsertRows();
    emit countChanged();
    if (select) setSelection(ids);
    changed();
}

void BoardModel::setNodeData(const QString &id, const QString &key, const QVariant &value) {
    const int r = indexOf(id);
    if (r < 0) return;
    const QJsonValue jv = QJsonValue::fromVariant(value);
    if (m_nodes[r].data.value(key) == jv && !jv.isNull()) return;
    snapshot();
    if (!value.isValid() || value.isNull()) m_nodes[r].data.remove(key); else m_nodes[r].data[key] = jv;
    emitRow(r);
    changed();
}

void BoardModel::setStyle(const QString &id, const QString &key, const QVariant &value) {
    const int r = indexOf(id);
    if (r < 0) return;
    snapshot();
    QJsonObject st = m_nodes[r].data.value("nodeStyle").toObject();
    if (!value.isValid() || value.isNull()) st.remove(key); else st[key] = QJsonValue::fromVariant(value);
    if (st.isEmpty()) m_nodes[r].data.remove("nodeStyle"); else m_nodes[r].data["nodeStyle"] = st;
    emitRow(r);
    changed();
}

void BoardModel::resetStyle(const QString &id) {
    const int r = indexOf(id);
    if (r < 0) return;
    snapshot();
    m_nodes[r].data.remove("nodeStyle");
    emitRow(r);
    changed();
}

void BoardModel::applyPreset(const QString &id, const QString &bg, const QString &border) {
    const int r = indexOf(id);
    if (r < 0) return;
    snapshot();
    QJsonObject st = m_nodes[r].data.value("nodeStyle").toObject();
    st["backgroundColor"] = bg; st["borderColor"] = border;
    m_nodes[r].data["nodeStyle"] = st;
    emitRow(r);
    changed();
}

void BoardModel::setLocked(bool locked) {
    if (m_selected.isEmpty()) return;
    snapshot();
    for (const auto &id : m_selected) {
        const int r = indexOf(id);
        if (r < 0) continue;
        if (locked) m_nodes[r].data["locked"] = true; else m_nodes[r].data.remove("locked");
        emitRow(r, {LockedRole});
    }
    emit selectionChanged();
    changed();
}

void BoardModel::deleteSelected() {
    if (!m_selectedEdge.isEmpty()) { deleteEdge(m_selectedEdge); return; }
    if (m_selected.isEmpty()) return;
    snapshot();
    const QSet<QString> ids = m_selected;
    m_edges->removeTouching(ids);
    for (int i = m_nodes.size() - 1; i >= 0; --i) {
        if (!ids.contains(m_nodes[i].id)) continue;
        beginRemoveRows({}, i, i);
        m_nodes.removeAt(i);
        rebuildIndex();
        endRemoveRows();
    }
    m_selected.clear();
    if (ids.contains(m_editing)) m_editing.clear();
    emit countChanged(); emit selectionChanged(); emit editingChanged();
    changed();
}

void BoardModel::bringToFront() {
    const QStringList ids = selectedIds();
    if (ids.isEmpty()) return;
    snapshot();
    for (const auto &id : ids) {
        const int r = indexOf(id);
        if (r < 0 || r == m_nodes.size() - 1) continue;
        beginMoveRows({}, r, r, {}, m_nodes.size());
        m_nodes.move(r, m_nodes.size() - 1);
        rebuildIndex();             // before the views look at the model again
        endMoveRows();
    }
    changed();
}

void BoardModel::sendToBack() {
    const QStringList ids = selectedIds();
    if (ids.isEmpty()) return;
    snapshot();
    for (int k = ids.size() - 1; k >= 0; --k) {
        const int r = indexOf(ids[k]);
        if (r <= 0) continue;
        beginMoveRows({}, r, r, {}, 0);
        m_nodes.move(r, 0);
        rebuildIndex();
        endMoveRows();
    }
    changed();
}

void BoardModel::duplicateSelected() {
    if (m_selected.isEmpty()) return;
    const QRectF box = selectionRect();
    pasteFrom(copySelection(), box.x() + 30, box.y() + 30, 0);
}

QJsonObject BoardModel::copySelection() const {
    QJsonArray ns, es;
    for (const auto &n : m_nodes) if (m_selected.contains(n.id)) ns.append(BoardJson::nodeToJson(n));
    for (const auto &e : m_edges->edges()) if (m_selected.contains(e.source) && m_selected.contains(e.target)) es.append(BoardJson::edgeToJson(e));
    return {{"nodes", ns}, {"edges", es}};
}

void BoardModel::pasteFrom(const QJsonObject &payload, double wx, double wy, int repeat) {
    QVector<NodeData> in;
    for (const auto &v : payload["nodes"].toArray()) in.append(BoardJson::nodeFromJson(v.toObject()));
    if (in.isEmpty()) return;
    double minX = in[0].x, minY = in[0].y;
    for (const auto &n : in) { minX = qMin(minX, n.x); minY = qMin(minY, n.y); }
    const double ox = wx - minX + 24.0 * repeat, oy = wy - minY + 24.0 * repeat;
    QHash<QString, QString> remap;
    for (auto &n : in) { const QString old = n.id; n.id = BoardJson::newId(); remap.insert(old, n.id); n.x += ox; n.y += oy; }
    snapshot();
    beginInsertRows({}, m_nodes.size(), m_nodes.size() + in.size() - 1);
    QSet<QString> ids;
    for (const auto &n : in) { m_nodes.append(n); m_index.insert(n.id, m_nodes.size() - 1); ids.insert(n.id); }
    endInsertRows();
    for (const auto &v : payload["edges"].toArray()) {
        EdgeData e = BoardJson::edgeFromJson(v.toObject());
        if (!remap.contains(e.source) || !remap.contains(e.target)) continue;
        e.id = BoardJson::newId(); e.source = remap[e.source]; e.target = remap[e.target];
        m_edges->append(e);
    }
    emit countChanged();
    setSelection(ids);
    changed();
}

// ── Arrange ──────────────────────────────────────────────────────────────

void BoardModel::align(const QString &mode) {
    QVector<int> rows;
    for (const auto &id : m_selected) { const int r = indexOf(id); if (r >= 0 && !lockedRow(r)) rows << r; }
    if (rows.size() < 2) return;
    QRectF box;
    for (int r : rows) box = box.isNull() ? nodeRect(r) : box.united(nodeRect(r));
    snapshot();
    QSet<QString> ids;
    for (int r : rows) {
        NodeData &n = m_nodes[r];
        if (mode == "left") n.x = box.left();
        else if (mode == "hcenter") n.x = box.center().x() - n.w / 2;
        else if (mode == "right") n.x = box.right() - n.w;
        else if (mode == "top") n.y = box.top();
        else if (mode == "vcenter") n.y = box.center().y() - n.h / 2;
        else if (mode == "bottom") n.y = box.bottom() - n.h;
        emitRow(r, {XRole, YRole});
        ids.insert(n.id);
    }
    emitGeometry(ids);
    changed();
}

void BoardModel::distribute(const QString &axis) {
    QVector<int> rows;
    for (const auto &id : m_selected) { const int r = indexOf(id); if (r >= 0 && !lockedRow(r)) rows << r; }
    if (rows.size() < 3) return;
    const bool horiz = axis == "h";
    std::sort(rows.begin(), rows.end(), [&](int a, int b) { return horiz ? m_nodes[a].x < m_nodes[b].x : m_nodes[a].y < m_nodes[b].y; });
    QRectF box;
    double total = 0;
    for (int r : rows) { box = box.isNull() ? nodeRect(r) : box.united(nodeRect(r)); total += horiz ? m_nodes[r].w : m_nodes[r].h; }
    const double gap = ((horiz ? box.width() : box.height()) - total) / (rows.size() - 1);
    snapshot();
    double cursor = horiz ? box.left() : box.top();
    QSet<QString> ids;
    for (int r : rows) {
        NodeData &n = m_nodes[r];
        if (horiz) { n.x = cursor; cursor += n.w + gap; } else { n.y = cursor; cursor += n.h + gap; }
        emitRow(r, {XRole, YRole});
        ids.insert(n.id);
    }
    emitGeometry(ids);
    changed();
}

void BoardModel::tidy() {
    QVector<int> rows;
    for (const auto &id : m_selected) { const int r = indexOf(id); if (r >= 0 && !lockedRow(r)) rows << r; }
    if (rows.size() < 2) return;
    // reading order: group into visual rows by vertical centre, then left to right inside each row
    auto cy = [&](int r) { return m_nodes[r].y + m_nodes[r].h / 2; };
    std::sort(rows.begin(), rows.end(), [&](int a, int b) { return cy(a) < cy(b); });
    QVector<QVector<int>> bands;
    for (int r : rows) {
        if (!bands.isEmpty()) {
            double sum = 0;
            for (int q : bands.last()) sum += cy(q);
            if (qAbs(cy(r) - sum / bands.last().size()) <= qMax(60.0, m_nodes[r].h * 0.6)) { bands.last().append(r); continue; }
        }
        bands.append({r});
    }
    rows.clear();
    for (auto &band : bands) {
        std::sort(band.begin(), band.end(), [&](int a, int b) { return m_nodes[a].x < m_nodes[b].x; });
        rows += band;
    }
    QRectF box;
    for (int r : rows) box = box.isNull() ? nodeRect(r) : box.united(nodeRect(r));
    const int cols = qMax(1, int(qCeil(qSqrt(double(rows.size())))));
    const double gap = 24;
    snapshot();
    QSet<QString> ids;
    double y = box.top();
    for (int i = 0; i < rows.size(); i += cols) {
        double x = box.left(), rowH = 0;
        for (int j = i; j < qMin<int>(i + cols, rows.size()); ++j) {
            NodeData &n = m_nodes[rows[j]];
            n.x = x; n.y = y;
            x += n.w + gap;
            rowH = qMax(rowH, n.h);
            emitRow(rows[j], {XRole, YRole});
            ids.insert(n.id);
        }
        y += rowH + gap;
    }
    emitGeometry(ids);
    changed();
}

// ── Connections ──────────────────────────────────────────────────────────

QString BoardModel::connectNodes(const QString &src, const QString &srcSide, const QString &dst, const QString &dstSide) {
    if (src == dst || !m_index.contains(src) || !m_index.contains(dst)) return {};
    if (m_edges->exists(src, srcSide, dst, dstSide)) return {};
    snapshot();
    EdgeData e;
    e.id = BoardJson::newId(); e.source = src; e.target = dst; e.sourceHandle = srcSide; e.targetHandle = dstSide;
    m_edges->append(e);
    changed();
    return e.id;
}

QString BoardModel::connectToNode(const QString &src, const QString &srcSide, const QString &dst, double wx, double wy) {
    const int r = indexOf(dst);
    if (r < 0) return {};
    const QRectF rc = nodeRect(r);
    // dropped on a node body: take the side nearest to where the pointer landed
    static const char *sides[] = {"top", "right", "bottom", "left"};
    QString best = "left";
    double bestD = 1e18;
    for (const char *s : sides) {
        const QPointF a = EdgeModel::anchor(rc, QLatin1String(s));
        const double d = qHypot(wx - a.x(), wy - a.y());
        if (d < bestD) { bestD = d; best = QString::fromLatin1(s); }
    }
    return connectNodes(src, srcSide, dst, best);
}

void BoardModel::setEdgeProp(const QString &id, const QString &key, const QVariant &value) {
    const int r = m_edges->indexOf(id);
    if (r < 0) return;
    snapshot();
    m_edges->setProp(r, key, value);
    changed();
}

void BoardModel::deleteEdge(const QString &id) {
    const int r = m_edges->indexOf(id);
    if (r < 0) return;
    snapshot();
    if (m_selectedEdge == id) { m_selectedEdge.clear(); emit selectionChanged(); }
    m_edges->removeAt(r);
    changed();
}

QVariantList BoardModel::curveFor(double x1, double y1, const QString &side1, double x2, double y2, const QString &side2) const {
    QString s2 = side2;
    if (s2.isEmpty()) {
        const QPointF d = EdgeModel::direction(side1);
        s2 = d.x() > 0 ? "left" : d.x() < 0 ? "right" : d.y() > 0 ? "top" : "bottom";
    }
    QPointF c1, c2;
    EdgeModel::controlPoints({x1, y1}, side1, {x2, y2}, s2, &c1, &c2);
    return {c1.x(), c1.y(), c2.x(), c2.y()};
}

QPointF BoardModel::handlePoint(const QString &id, const QString &side) const {
    const int r = indexOf(id);
    return r < 0 ? QPointF() : EdgeModel::anchor(nodeRect(r), side);
}

QPointF BoardModel::edgeMid(const QString &id) const {
    const int r = m_edges->indexOf(id);
    return r < 0 ? QPointF() : m_edges->geoFor(m_edges->edges()[r]).mid;
}

QVariantMap BoardModel::edgeInfo(const QString &id) const {
    const int r = m_edges->indexOf(id);
    if (r < 0) return {};
    const EdgeData &e = m_edges->edges()[r];
    const auto g = m_edges->geoFor(e);
    return {{"id", e.id}, {"label", e.label}, {"color", e.data.value("color").toString()}, {"strokeWidth", e.data.value("strokeWidth").toDouble(1.5)},
            {"dashed", e.data.value("dashed").toBool(false)}, {"arrow", e.data.value("arrow").toBool(false)}, {"midX", g.mid.x()}, {"midY", g.mid.y()}};
}
