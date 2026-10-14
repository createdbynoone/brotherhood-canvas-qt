#include "cullproxy.h"

#include "boardmodel.h"
#include "edgemodel.h"

CullProxy::CullProxy(BoardModel *board, EdgeModel *edges, QObject *parent) : QSortFilterProxyModel(parent), m_board(board), m_edges(edges) {
    setDynamicSortFilter(false);                 // BoardModel calls refilter() itself, exactly when something relevant changed
    setSourceModel(edges ? static_cast<QAbstractItemModel *>(edges) : static_cast<QAbstractItemModel *>(board));
}

void CullProxy::setRect(const QRectF &r) {
    if (r == m_rect) return;
    m_rect = r;
    invalidateFilter();
}

bool CullProxy::filterAcceptsRow(int row, const QModelIndex &) const {
    if (!m_edges) {
        const NodeData &n = m_board->nodes()[row];
        if (m_board->isSelected(n.id) || n.id == m_board->editingId()) return true;
        return QRectF(n.x, n.y, n.w, n.h).intersects(m_rect);
    }
    const EdgeData &e = m_edges->edges()[row];
    if (e.id == m_board->selectedEdge()) return true;
    const auto g = m_edges->geoFor(e);
    if (!g.ok) return false;
    const QRectF box = QRectF(g.p1, g.p2).normalized().united(QRectF(g.c1, g.c2).normalized());
    return box.adjusted(-40, -40, 40, 40).intersects(m_rect);
}

int CullProxy::rowOf(const QString &id) const {
    const int src = m_board->indexOf(id);
    if (src < 0) return -1;
    const QModelIndex p = mapFromSource(m_board->index(src, 0));
    return p.isValid() ? p.row() : -1;
}
