#include "boardsmodel.h"

QHash<int, QByteArray> BoardsModel::roleNames() const {
    return {{IdRole, "boardId"}, {NameRole, "name"}, {CountRole, "nodeCount"}, {UpdatedRole, "updatedAt"}};
}

QVariant BoardsModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_items.size()) return {};
    const BoardMeta &m = m_items[index.row()];
    switch (role) {
    case IdRole: return m.id;
    case NameRole: return m.name;
    case CountRole: return m.nodeCount;
    case UpdatedRole: return m.updatedAt;
    default: return {};
    }
}

void BoardsModel::setItems(const QVector<BoardMeta> &items) {
    beginResetModel();
    m_items = items;
    endResetModel();
}

int BoardsModel::indexOf(const QString &id) const {
    for (int i = 0; i < m_items.size(); ++i) if (m_items[i].id == id) return i;
    return -1;
}

void BoardsModel::append(const BoardMeta &m) {
    beginInsertRows({}, m_items.size(), m_items.size());
    m_items.append(m);
    endInsertRows();
}

void BoardsModel::update(const QString &id, const QString &name, int count, const QString &updatedAt) {
    const int r = indexOf(id);
    if (r < 0) return;
    m_items[r].name = name; m_items[r].nodeCount = count; m_items[r].updatedAt = updatedAt;
    emit dataChanged(index(r), index(r));
}

void BoardsModel::remove(const QString &id) {
    const int r = indexOf(id);
    if (r < 0) return;
    beginRemoveRows({}, r, r);
    m_items.removeAt(r);
    endRemoveRows();
}

void BoardsModel::move(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= m_items.size() || to >= m_items.size()) return;
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_items.move(from, to);
    endMoveRows();
}

int BoardsModel::matchCount(const QString &query) const {
    int n = 0;
    for (const auto &m : m_items) if (query.isEmpty() || m.name.contains(query, Qt::CaseInsensitive)) ++n;
    return n;
}

QVariantList BoardsModel::list() const {
    QVariantList out;
    for (const auto &m : m_items) out.append(QVariantMap{{"id", m.id}, {"name", m.name}});
    return out;
}
