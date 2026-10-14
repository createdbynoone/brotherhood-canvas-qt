#pragma once
#include <QRectF>
#include <QSortFilterProxyModel>

class BoardModel;
class EdgeModel;

// The part of the board near the camera. QML builds items only for these rows, so panning a board with thousands of
// nodes costs what the visible handful costs. Selected and editing nodes always stay, even when scrolled out of view.
class CullProxy : public QSortFilterProxyModel {
    Q_OBJECT
public:
    CullProxy(BoardModel *board, EdgeModel *edges, QObject *parent = nullptr);   // edges == nullptr: the node list
    void setRect(const QRectF &r);
    void refilter() { invalidateFilter(); }
    Q_INVOKABLE int rowOf(const QString &id) const;                              // proxy row of a node, or -1

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &) const override;

private:
    BoardModel *m_board;
    EdgeModel *m_edges;
    QRectF m_rect = QRectF(-1e9, -1e9, 2e9, 2e9);
};
