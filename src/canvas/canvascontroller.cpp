#include "canvascontroller.h"

#include "../core/prefs.h"
#include "../platform/mac.h"
#include "exporter.h"
#include "mediaprovider.h"

#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QMimeData>
#include <QtConcurrent>

static const char *kMime = "application/x-brotherhood-canvas";

CanvasController::CanvasController(QObject *parent) : QObject(parent) {
    m_io.setMaxThreadCount(1);          // every vault write goes through here, in order
    m_work.setMaxThreadCount(2);
    m_saveTimer.setSingleShot(true); m_saveTimer.setInterval(1500);
    m_viewTimer.setSingleShot(true); m_viewTimer.setInterval(2500);
    connect(&m_saveTimer, &QTimer::timeout, this, &CanvasController::saveNow);
    connect(&m_viewTimer, &QTimer::timeout, this, &CanvasController::saveNow);
    connect(&m_board, &BoardModel::modified, this, &CanvasController::saveSoon);
    connect(&m_board, &BoardModel::viewportModified, this, [this] { if (!m_loading && !m_board.boardId().isEmpty()) m_viewTimer.start(); });
    connect(&m_board, &BoardModel::toast, this, &CanvasController::toast);
}

void CanvasController::setState(const QString &s, const QString &msg) {
    m_state = s; m_message = msg;
    emit stateChanged();
}

void CanvasController::start() {
    const QString path = qEnvironmentVariable("BCQ_VAULT", Prefs::vaultPath());
    if (path.isEmpty()) { setState("welcome"); return; }
    if (!Vault::isVault(path)) {
        setState("welcome", QStringLiteral("The vault at %1 could not be found. Connect its disk or choose another vault.").arg(path));
        return;
    }
    openVault(path);
}

bool CanvasController::openVault(const QString &path) {
    if (!Vault::isVault(path)) {
        setState("welcome", QStringLiteral("That folder is not a Brotherhood Canvas vault. Create a new vault instead."));
        return false;
    }
    flush();
    m_vault = Vault(path);
    if (qEnvironmentVariableIsEmpty("BCQ_VAULT")) Prefs::setVaultPath(path);
    afterVaultOpened();
    return true;
}

bool CanvasController::createVault(const QString &path) {
    QString err;
    const QString name = QFileInfo(path).fileName().isEmpty() ? QStringLiteral("My Canvas") : QFileInfo(path).fileName();
    if (!Vault::create(path, name, &err)) { setState("welcome", err); return false; }
    return openVault(path);
}

void CanvasController::afterVaultOpened() {
    MediaProvider::setRoot(m_vault.path());
    m_board.setVaultRoot(m_vault.path());
    auto list = m_vault.listBoards();
    if (list.isEmpty()) list.append(m_vault.createBoard(QStringLiteral("Board 1")));
    m_boards.setItems(list);
    QString target = Prefs::lastBoardId();
    if (m_boards.indexOf(target) < 0) target = list.first().id;
    emit vaultChanged();
    // the last board may be unreadable: fall back to the next one that opens
    QStringList order{target};
    for (const auto &m : list) if (m.id != target) order << m.id;
    for (const QString &id : order) {
        loadBoard(id);
        if (m_board.boardId() == id) { setState("ready"); return; }
    }
    m_vault = Vault();
    setState("welcome", QStringLiteral("None of the boards in this vault could be read. The files may be damaged."));
}

void CanvasController::closeVault() {
    flush();
    m_loading = true; m_board.clear(); m_loading = false;
    m_boards.setItems({});
    m_vault = Vault();
    Prefs::setVaultPath(QString());
    emit vaultChanged(); emit currentChanged();
    setState("welcome");
}

void CanvasController::loadBoard(const QString &id) {
    m_io.waitForDone();
    BoardData b;
    if (!m_vault.readBoard(id, &b)) { emit toast(QStringLiteral("Could not open that board"), 2); return; }
    m_loading = true;
    m_board.load(b);
    m_loading = false;
    m_board.setSnapEnabled(Prefs::ownBool("snap", true));
    Prefs::setLastBoardId(id);
    emit currentChanged();
}

void CanvasController::openBoard(const QString &id) {
    if (id == m_board.boardId() || m_boards.indexOf(id) < 0) return;
    saveNow();
    loadBoard(id);
}

QString CanvasController::nextBoardName() const {
    int n = m_boards.rowCount() + 1;
    auto taken = [&](int k) { for (const auto &m : m_boards.items()) if (m.name == QStringLiteral("Board %1").arg(k)) return true; return false; };
    while (taken(n)) ++n;
    return QStringLiteral("Board %1").arg(n);
}

QString CanvasController::newBoard() {
    if (!m_vault.valid()) return {};
    saveNow();
    m_io.waitForDone();
    const BoardMeta meta = m_vault.createBoard(nextBoardName());
    m_boards.append(meta);
    loadBoard(meta.id);
    return meta.id;
}

void CanvasController::renameBoard(const QString &id, const QString &name) {
    const QString n = name.trimmed();
    const int row = m_boards.indexOf(id);
    if (n.isEmpty() || row < 0 || m_boards.items()[row].name == n) return;
    const auto cur = m_boards.items()[row];
    m_boards.update(id, n, cur.nodeCount, cur.updatedAt);
    if (id == m_board.boardId()) {
        m_board.setBoardName(n);
        saveNow();
        return;
    }
    const Vault v = m_vault;
    (void)QtConcurrent::run(&m_io, [v, id, n] {
        BoardData b;
        if (v.readBoard(id, &b)) { b.name = n; v.writeBoard(b); }
    });
}

void CanvasController::deleteBoard(const QString &id) {
    const int row = m_boards.indexOf(id);
    if (row < 0) return;
    const bool wasCurrent = id == m_board.boardId();
    if (wasCurrent) { m_saveTimer.stop(); m_viewTimer.stop(); }
    const Vault v = m_vault;
    (void)QtConcurrent::run(&m_io, [v, id] { v.deleteBoard(id); });
    m_boards.remove(id);
    if (wasCurrent) {
        if (m_boards.rowCount() == 0) {
            m_io.waitForDone();
            m_boards.append(m_vault.createBoard(QStringLiteral("Board 1")));
        }
        loadBoard(m_boards.items()[qMin(row, m_boards.rowCount() - 1)].id);
    }
}

void CanvasController::moveBoard(int from, int to) {
    m_boards.move(from, to);
    persistIndex();
}

void CanvasController::persistIndex() {
    const Vault v = m_vault;
    const auto items = m_boards.items();
    (void)QtConcurrent::run(&m_io, [v, items] { v.writeIndex(items); });
}

void CanvasController::saveSoon() {
    if (m_loading || m_board.boardId().isEmpty() || !m_vault.valid()) return;
    m_saveTimer.start();
}

void CanvasController::saveNow() {
    m_saveTimer.stop(); m_viewTimer.stop();
    if (m_loading || m_board.boardId().isEmpty() || !m_vault.valid()) return;
    const BoardData b = m_board.toBoardData();
    m_boards.update(b.id, b.name, b.nodes.size(), b.updatedAt);
    const Vault v = m_vault;
    (void)QtConcurrent::run(&m_io, [this, v, b] {
        if (!v.writeBoard(b)) QMetaObject::invokeMethod(this, [this] { emit toast(QStringLiteral("Could not save the board. Is the vault disk connected?"), 2); }, Qt::QueuedConnection);
    });
}

void CanvasController::flush() {
    saveNow();
    m_io.waitForDone();
}

// ── Clipboard ────────────────────────────────────────────────────────────

void CanvasController::copySelection() {
    if (m_board.selectedCount() == 0) return;
    auto *md = new QMimeData;
    md->setData(kMime, QJsonDocument(m_board.copySelection()).toJson(QJsonDocument::Compact));
    QStringList texts;
    for (const auto &n : m_board.selectedNodes()) {
        const QString c = n.data.value("content").toString();
        if (!c.isEmpty()) texts << c;
        else if (!n.data.value("fileName").toString().isEmpty()) texts << n.data.value("fileName").toString();
    }
    md->setText(texts.join("\n\n"));
    QGuiApplication::clipboard()->setMimeData(md);
    m_pasteRepeat = 0;
}

void CanvasController::cutSelection() {
    copySelection();
    m_board.deleteSelected();
}

bool CanvasController::canPaste() const {
    const QMimeData *md = QGuiApplication::clipboard()->mimeData();
    if (!md) return false;
    if (md->hasFormat(kMime) || md->hasImage()) return true;
    if (md->hasUrls()) for (const auto &u : md->urls()) if (u.isLocalFile()) return true;
    return md->hasText() && !md->text().trimmed().isEmpty();
}

void CanvasController::paste(double wx, double wy) {
    const QMimeData *md = QGuiApplication::clipboard()->mimeData();
    if (!md) return;
    if (md->hasFormat(kMime)) {
        const auto doc = QJsonDocument::fromJson(md->data(kMime));
        if (doc.isObject()) { m_board.pasteFrom(doc.object(), wx, wy, m_pasteRepeat++); return; }
    }
    if (md->hasUrls()) {
        QList<QUrl> local;
        for (const auto &u : md->urls()) if (u.isLocalFile()) local << u;
        if (!local.isEmpty()) { importUrls(local, wx, wy); return; }
    }
    if (md->hasImage()) {
        const QImage img = qvariant_cast<QImage>(md->imageData());
        if (!img.isNull()) {
            ++m_importing; emit importingChanged();
            const Vault v = m_vault;
            const QString bid = m_board.boardId();
            auto *w = new QFutureWatcher<ImportedFile>(this);
            connect(w, &QFutureWatcher<ImportedFile>::finished, this, [this, w, wx, wy, bid] {
                --m_importing; emit importingChanged();
                placeImported(bid, {w->result()}, wx, wy);
                w->deleteLater();
            });
            w->setFuture(QtConcurrent::run(&m_work, [v, img] { return v.importImage(img); }));
            return;
        }
    }
    if (md->hasText() && !md->text().trimmed().isEmpty()) {
        const QString id = m_board.addNode("text", wx + 130, wy + 90);
        m_board.setNodeData(id, "content", md->text().left(60000));
    }
}

// ── Imports ──────────────────────────────────────────────────────────────

void CanvasController::importUrls(const QList<QUrl> &urls, double wx, double wy) {
    QStringList paths;
    for (const auto &u : urls) if (u.isLocalFile() && QFileInfo(u.toLocalFile()).isFile()) paths << u.toLocalFile();
    if (!paths.isEmpty()) importPaths(paths, wx, wy);
}

void CanvasController::importPaths(const QStringList &paths, double wx, double wy) {
    if (!m_vault.valid()) return;
    m_importing += paths.size(); emit importingChanged();
    const Vault v = m_vault;
    const QString bid = m_board.boardId();
    auto *w = new QFutureWatcher<QVector<ImportedFile>>(this);
    connect(w, &QFutureWatcher<QVector<ImportedFile>>::finished, this, [this, w, wx, wy, bid, n = paths.size()] {
        m_importing -= n; emit importingChanged();
        placeImported(bid, w->result(), wx, wy);
        w->deleteLater();
    });
    w->setFuture(QtConcurrent::run(&m_work, [v, paths] {
        QVector<ImportedFile> out;
        for (const auto &p : paths) out.append(v.importFile(p));
        return out;
    }));
}

static QSizeF fitSize(const ImportedFile &f) {
    if (f.nodeType == "image" || f.nodeType == "video") {
        if (f.pixelW <= 0 || f.pixelH <= 0) return f.nodeType == "image" ? QSizeF(240, 200) : QSizeF(280, 200);
        const double r = qMin(1.0, qMin(480.0 / f.pixelW, 480.0 / f.pixelH));
        return {double(qRound(f.pixelW * r)), double(qRound(f.pixelH * r))};
    }
    if (f.nodeType == "pdf") return {200, 220};
    if (f.nodeType == "text") return {260, 180};
    return {200, 160};
}

void CanvasController::placeImported(const QString &boardId, const QVector<ImportedFile> &files, double wx, double wy) {
    QVector<NodeData> nodes;
    double x = wx;
    QString firstError;
    for (const auto &f : files) {
        if (!f.ok) { if (firstError.isEmpty()) firstError = f.error; continue; }
        NodeData n;
        n.id = BoardJson::newId(); n.type = f.nodeType;
        const QSizeF s = fitSize(f);
        n.w = s.width(); n.h = s.height(); n.x = x; n.y = wy;
        n.data["filePath"] = f.relPath;
        n.data["fileName"] = f.fileName;
        n.data["mimeType"] = f.mimeType;
        n.data["fileSize"] = double(f.fileSize);
        n.data["content"] = f.content;
        if (!f.thumbRel.isEmpty()) n.data["thumbnailPath"] = f.thumbRel;
        nodes.append(n);
        x += n.w + 20;
    }
    if (!firstError.isEmpty()) emit toast(firstError, 2);
    if (nodes.isEmpty()) return;
    QRectF area;
    for (const auto &n : nodes) area = area.isNull() ? QRectF(n.x, n.y, n.w, n.h) : area.united(QRectF(n.x, n.y, n.w, n.h));
    if (boardId == m_board.boardId()) {
        m_board.insertNodes(nodes);
        emit placed(area);
        return;
    }
    // the user moved to another board while the files were copying: put them where they were dropped
    const Vault v = m_vault;
    (void)QtConcurrent::run(&m_io, [v, boardId, nodes] {
        BoardData b;
        if (!v.readBoard(boardId, &b)) return;
        b.nodes += nodes;
        b.updatedAt = BoardJson::nowIso();
        v.writeBoard(b);
    });
    const int row = m_boards.indexOf(boardId);
    emit toast(QStringLiteral("Added %1 item(s) to %2").arg(nodes.size()).arg(row >= 0 ? m_boards.items()[row].name : QStringLiteral("the previous board")), 1);
}

void CanvasController::addText(double wx, double wy, const QString &type) {
    const QString id = m_board.addNode(type, wx, wy);
    m_board.setEditingId(id);
}

void CanvasController::revealNode(const QString &id) {
    const QString p = m_board.filePathOf(id);
    if (!p.isEmpty()) Mac::revealInFinder(p);
}

void CanvasController::openNodeFile(const QString &id) {
    const QString p = m_board.filePathOf(id);
    if (!p.isEmpty()) QDesktopServices::openUrl(QUrl::fromLocalFile(p));
}

// ── Export ───────────────────────────────────────────────────────────────

void CanvasController::exportBoard(const QUrl &file, bool selectionOnly) {
    if (m_exporting || !m_vault.valid()) return;
    QString out = file.toLocalFile();
    if (out.isEmpty()) return;
    if (!out.endsWith(".png", Qt::CaseInsensitive) && !out.endsWith(".pdf", Qt::CaseInsensitive) && !out.endsWith(".jpg", Qt::CaseInsensitive)) out += ".png";
    const BoardData b = m_board.toBoardData();
    QSet<QString> only;
    if (selectionOnly) for (const auto &id : m_board.selectedIds()) only.insert(id);
    const QString root = m_vault.path();
    const QString brand = qApp->property("brandFamily").toString();
    m_exporting = true; emit exportingChanged();
    auto *w = new QFutureWatcher<QString>(this);
    connect(w, &QFutureWatcher<QString>::finished, this, [this, w, out] {
        m_exporting = false; emit exportingChanged();
        const QString err = w->result();
        if (err.isEmpty()) { emit toast(QStringLiteral("Exported %1").arg(QFileInfo(out).fileName()), 1); Mac::revealInFinder(out); }
        else emit toast(err, 2);
        w->deleteLater();
    });
    w->setFuture(QtConcurrent::run(&m_work, [b, only, root, out, brand] { return Exporter::render(b, only, root, out, brand); }));
}
