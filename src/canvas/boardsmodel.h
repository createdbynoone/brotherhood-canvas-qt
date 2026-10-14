#pragma once
#include "vault.h"

#include <QAbstractListModel>

// The sidebar list: one row per board, in the order stored in boards/index.json.
class BoardsModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { IdRole = Qt::UserRole + 1, NameRole, CountRole, UpdatedRole };
    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex & = {}) const override { return m_items.size(); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    const QVector<BoardMeta> &items() const { return m_items; }
    Q_INVOKABLE int matchCount(const QString &query) const;
    Q_INVOKABLE QVariantList list() const;
    void setItems(const QVector<BoardMeta> &items);
    int indexOf(const QString &id) const;
    void append(const BoardMeta &m);
    void update(const QString &id, const QString &name, int count, const QString &updatedAt);
    void remove(const QString &id);
    void move(int from, int to);        // `to` is the final row of the moved board

private:
    QVector<BoardMeta> m_items;
};
