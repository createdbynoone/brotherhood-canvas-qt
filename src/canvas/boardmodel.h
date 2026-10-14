#pragma once
#include "boarddata.h"

#include <QAbstractListModel>
#include <QHash>
#include <QPointF>
#include <QRectF>
#include <QSet>
#include <QVariantList>
#include <QVariantMap>

#include "edgemodel.h"
#include "cullproxy.h"

// The open board: one row per node, in stacking order (last row paints on top). All geometry and editing logic
// lives here, in world coordinates; QML only draws and forwards pointer input. Every mutation goes through
// `snapshot()` first, so undo / redo is a stack of whole-board copies (cheap: QJson data is implicitly shared).
class BoardModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString boardId READ boardId NOTIFY boardChanged)
    Q_PROPERTY(QString boardName READ boardName NOTIFY boardChanged)
    Q_PROPERTY(QString background READ background WRITE setBackground NOTIFY backgroundChanged)
    Q_PROPERTY(EdgeModel *edges READ edges CONSTANT)
    Q_PROPERTY(CullProxy *visibleNodes READ visibleNodes CONSTANT)     // what QML instantiates: nodes near the camera
    Q_PROPERTY(CullProxy *visibleEdges READ visibleEdges CONSTANT)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedId READ selectedId NOTIFY selectionChanged)         // set only for a single selection
    Q_PROPERTY(QString selectedType READ selectedType NOTIFY selectionChanged)
    Q_PROPERTY(QString selectedEdge READ selectedEdge NOTIFY selectionChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(QVariantList guides READ guides NOTIFY guidesChanged)
    Q_PROPERTY(QRectF bounds READ bounds NOTIFY boundsChanged)                     // union of every node, world units
    Q_PROPERTY(QRectF selectionBounds READ selectionRect NOTIFY boundsChanged)     // union of the selected nodes
    Q_PROPERTY(double vx READ vx NOTIFY viewportLoaded)
    Q_PROPERTY(double vy READ vy NOTIFY viewportLoaded)
    Q_PROPERTY(double zoom READ zoom NOTIFY viewportLoaded)
    Q_PROPERTY(QString editingId READ editingId WRITE setEditingId NOTIFY editingChanged)
    Q_PROPERTY(QString labelEditId READ labelEditId WRITE setLabelEditId NOTIFY editingChanged)
    Q_PROPERTY(bool snapEnabled READ snapEnabled WRITE setSnapEnabled NOTIFY snapChanged)
    Q_PROPERTY(bool hasSelectionLocked READ hasSelectionLocked NOTIFY selectionChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1, TypeRole, XRole, YRole, WRole, HRole, SelectedRole, ContentRole, LabelRole, LockedRole,
        FilePathRole, FileAbsRole, FileNameRole, FileSizeRole, ThumbPathRole, NoteColorRole, FontSizeRole,
        StyleBgRole, StyleBorderRole, StyleBorderWRole, StyleRadiusRole, StyleOpacityRole, HasStyleRole, EditingRole
    };

    explicit BoardModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex & = {}) const override { return m_nodes.size(); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Board lifecycle
    void setVaultRoot(const QString &path) { m_vaultRoot = path; }
    void load(const BoardData &b);
    BoardData toBoardData();                         // current state with updatedAt refreshed
    void clear();
    QString boardId() const { return m_id; }
    QString boardName() const { return m_name; }
    void setBoardName(const QString &n) { m_name = n; emit boardChanged(); }
    QString background() const { return m_background; }
    void setBackground(const QString &b);
    EdgeModel *edges() const { return m_edges; }
    CullProxy *visibleNodes() const { return m_visNodes; }
    CullProxy *visibleEdges() const { return m_visEdges; }
    Q_INVOKABLE void setCull(double l, double t, double r, double b);
    void refilter() { m_visNodes->refilter(); m_visEdges->refilter(); }
    double vx() const { return m_vx; }
    double vy() const { return m_vy; }
    double zoom() const { return m_zoom; }
    bool snapEnabled() const { return m_snap; }
    void setSnapEnabled(bool on) { if (m_snap != on) { m_snap = on; emit snapChanged(); } }

    int selectedCount() const { return m_selected.size(); }
    QString selectedId() const { return m_selected.size() == 1 ? *m_selected.begin() : QString(); }
    QString selectedType() const;
    QString selectedEdge() const { return m_selectedEdge; }
    bool hasSelectionLocked() const;
    bool canUndo() const { return !m_undo.isEmpty(); }
    bool canRedo() const { return !m_redo.isEmpty(); }
    QVariantList guides() const { return m_guides; }
    QRectF bounds() const;
    QString editingId() const { return m_editing; }
    void setEditingId(const QString &id);
    QString labelEditId() const { return m_labelEdit; }
    void setLabelEditId(const QString &id);

    // Hit testing and pointer gestures (world coordinates; `zoom` makes the tolerances screen-constant)
    Q_INVOKABLE QVariantMap hit(double wx, double wy, double zoom) const;
    Q_INVOKABLE void beginGesture();
    Q_INVOKABLE void endGesture();
    Q_INVOKABLE void beginMove(const QString &id);
    Q_INVOKABLE void moveBy(double dx, double dy, double zoom, bool snap);     // cumulative from beginMove
    Q_INVOKABLE void endMove();
    Q_INVOKABLE void beginResize(const QString &id, int handle);
    Q_INVOKABLE void resizeBy(double dx, double dy, bool freeAspect);          // cumulative from beginResize
    Q_INVOKABLE void endResize();
    Q_INVOKABLE void beginMarquee(bool additive);
    Q_INVOKABLE void marquee(double x0, double y0, double x1, double y1);

    // Selection
    Q_INVOKABLE void selectOnly(const QString &id);
    Q_INVOKABLE void toggleSelected(const QString &id);
    Q_INVOKABLE void selectAll();
    Q_INVOKABLE void clearSelection();
    Q_INVOKABLE void selectEdge(const QString &id);
    Q_INVOKABLE bool isSelected(const QString &id) const { return m_selected.contains(id); }
    Q_INVOKABLE void selectIds(const QStringList &ids);

    // Editing
    Q_INVOKABLE QString addNode(const QString &type, double x, double y, double w = 0, double h = 0);   // returns id
    Q_INVOKABLE void setNodeData(const QString &id, const QString &key, const QVariant &value);
    Q_INVOKABLE void setStyle(const QString &id, const QString &key, const QVariant &value);           // null removes
    Q_INVOKABLE void resetStyle(const QString &id);
    Q_INVOKABLE void applyPreset(const QString &id, const QString &bg, const QString &border);
    Q_INVOKABLE void setLocked(bool locked);
    Q_INVOKABLE void deleteSelected();
    Q_INVOKABLE void duplicateSelected();
    Q_INVOKABLE void bringToFront();
    Q_INVOKABLE void sendToBack();
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void align(const QString &mode);          // left | hcenter | right | top | vcenter | bottom
    Q_INVOKABLE void distribute(const QString &axis);     // h | v
    Q_INVOKABLE void tidy();                              // pack the selection into a tidy grid

    // Connections
    Q_INVOKABLE QString connectNodes(const QString &src, const QString &srcSide, const QString &dst, const QString &dstSide);
    Q_INVOKABLE QString connectToNode(const QString &src, const QString &srcSide, const QString &dst, double wx, double wy);
    Q_INVOKABLE void setEdgeProp(const QString &id, const QString &key, const QVariant &value);
    Q_INVOKABLE void deleteEdge(const QString &id);
    Q_INVOKABLE QVariantList curveFor(double x1, double y1, const QString &side1, double x2, double y2, const QString &side2) const;
    Q_INVOKABLE QPointF handlePoint(const QString &id, const QString &side) const;
    Q_INVOKABLE QPointF edgeMid(const QString &id) const;
    Q_INVOKABLE QVariantMap edgeInfo(const QString &id) const;

    // Clipboard (payload is owned by the controller so it survives board switches)
    QJsonObject copySelection() const;
    void pasteFrom(const QJsonObject &payload, double wx, double wy, int repeat);
    void insertNodes(const QVector<NodeData> &nodes, bool select = true);       // used by file imports

    // Queries
    Q_INVOKABLE QRectF rectOf(const QString &id) const;
    Q_INVOKABLE QRectF selectionRect() const;
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 12) const;
    Q_INVOKABLE QVariantMap nodeInfo(const QString &id) const;
    Q_INVOKABLE void setViewport(double x, double y, double z);
    Q_INVOKABLE QStringList selectedIds() const;
    Q_INVOKABLE QStringList ids() const;                                        // every node id, in stacking order
    Q_INVOKABLE QString filePathOf(const QString &id) const;                    // absolute, empty when none
    QVector<NodeData> selectedNodes() const;
    const QVector<NodeData> &nodes() const { return m_nodes; }
    Q_INVOKABLE int indexOf(const QString &id) const { return m_index.value(id, -1); }
    QRectF nodeRect(int row) const { const auto &n = m_nodes[row]; return QRectF(n.x, n.y, n.w, n.h); }

signals:
    void boardChanged();
    void backgroundChanged();
    void countChanged();
    void selectionChanged();
    void historyChanged();
    void guidesChanged();
    void boundsChanged();
    void viewportLoaded();
    void editingChanged();
    void snapChanged();
    void modified();                 // content changed: schedule an autosave
    void viewportModified();         // only the camera moved
    void toast(const QString &msg, int kind);

private:
    friend class EdgeModel;
    struct Snap { QVector<NodeData> nodes; QVector<EdgeData> edges; };

    void snapshot();
    void restore(const Snap &s);
    void rebuildIndex();
    void emitRow(int row, const QList<int> &roles = {});
    void emitGeometry(const QSet<QString> &ids);
    void setSelection(const QSet<QString> &ids, const QString &edge = {});
    void changed();                  // mark dirty + bounds
    QSizeF minSize(const QString &type) const;
    bool lockedRow(int row) const { return m_nodes[row].data.value("locked").toBool(); }
    static QSizeF defaultSize(const QString &type);

    QVector<NodeData> m_nodes;
    QHash<QString, int> m_index;
    QSet<QString> m_selected;
    QString m_selectedEdge;
    EdgeModel *m_edges;
    CullProxy *m_visNodes, *m_visEdges;
    bool m_contentDirty = false;
    QString m_updatedAt;
    QString m_id, m_name, m_createdAt, m_background = "dots", m_vaultRoot;
    QJsonObject m_extra;
    double m_vx = 0, m_vy = 0, m_zoom = 1;
    bool m_snap = true;
    QString m_editing, m_labelEdit;

    QVector<Snap> m_undo, m_redo;
    bool m_gesture = false, m_gestureSnapped = false;
    QVariantList m_guides;

    // Move / resize gesture state
    struct Origin { QString id; double x, y; };
    QVector<Origin> m_moveOrigins;
    bool m_moved = false;
    QString m_resizeId;
    int m_resizeHandle = -1;
    QRectF m_resizeStart;
    bool m_resized = false;
    QSet<QString> m_marqueeBase;
};
