#pragma once
#include "boarddata.h"

#include <QAbstractListModel>
#include <QPointF>
#include <QRectF>
#include <QSet>

class BoardModel;

// Connections between nodes. Each row carries its resolved bezier (anchor points, two control points, label
// position) so QML only has to draw it; geometry is recomputed from the node rectangles whenever they move.
class EdgeModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        IdRole = Qt::UserRole + 1, X1Role, Y1Role, X2Role, Y2Role, C1XRole, C1YRole, C2XRole, C2YRole, MidXRole, MidYRole,
        LabelRole, ColorRole, WidthRole, DashedRole, ArrowRole, SelectedRole, SrcSideRole, DstSideRole, AngleRole
    };
    struct Geo { QPointF p1, p2, c1, c2, mid; double endAngle = 0; bool ok = false; };

    explicit EdgeModel(BoardModel *board);

    int rowCount(const QModelIndex & = {}) const override { return m_edges.size(); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    const QVector<EdgeData> &edges() const { return m_edges; }
    void reset(const QVector<EdgeData> &e);
    int indexOf(const QString &id) const;
    void append(const EdgeData &e);
    void removeAt(int row);
    void removeTouching(const QSet<QString> &nodeIds);
    void nodesMoved(const QSet<QString> &nodeIds);
    void refreshSelection(const QString &oldId, const QString &newId);
    void refreshAll();
    void setProp(int row, const QString &key, const QVariant &value);
    bool exists(const QString &src, const QString &sh, const QString &dst, const QString &dh) const;

    Geo geoFor(const EdgeData &e) const;
    QString hitTest(double wx, double wy, double tol) const;     // nearest edge id within tol, or empty

    static QPointF anchor(const QRectF &r, const QString &side);
    static QPointF direction(const QString &side);
    static void controlPoints(const QPointF &p1, const QString &s1, const QPointF &p2, const QString &s2, QPointF *c1, QPointF *c2);
    static QPointF bezier(const QPointF &p1, const QPointF &c1, const QPointF &c2, const QPointF &p2, double t);

private:
    BoardModel *m_board;
    QVector<EdgeData> m_edges;
};
