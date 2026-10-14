#include "vault.h"

#include "../core/jsonfile.h"
#include "../platform/mac.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QSaveFile>

bool Vault::isVault(const QString &path) { return QFileInfo::exists(path + "/vault.json") && QFileInfo(path + "/boards").isDir(); }

bool Vault::create(const QString &path, const QString &name, QString *error) {
    if (!QDir().mkpath(path + "/boards") || !QDir().mkpath(path + "/attachments")) {
        if (error) *error = QStringLiteral("Could not create the folder");
        return false;
    }
    if (!QFileInfo::exists(path + "/vault.json")) {
        QJsonObject o{{"version", "1.0"}, {"name", name}, {"createdAt", BoardJson::nowIso()}};
        if (!JsonFile::writeObject(path + "/vault.json", o)) { if (error) *error = QStringLiteral("Could not write vault.json"); return false; }
    }
    if (!QFileInfo::exists(path + "/boards/index.json")) JsonFile::writeObject(path + "/boards/index.json", QJsonObject{{"boards", QJsonArray()}});
    return true;
}

QString Vault::name() const { return JsonFile::readObject(m_path + "/vault.json").value("name").toString("My Canvas"); }

QVector<BoardMeta> Vault::listBoards() const {
    QVector<BoardMeta> out;
    for (const auto &v : JsonFile::readObject(m_path + "/boards/index.json")["boards"].toArray()) {
        const auto o = v.toObject();
        BoardMeta m{o["id"].toString(), o["name"].toString(), o["createdAt"].toString(), o["updatedAt"].toString(), o["nodeCount"].toInt()};
        if (BoardJson::safeId(m.id)) out.append(m);
    }
    return out;
}

bool Vault::writeIndex(const QVector<BoardMeta> &boards) const {
    QJsonArray a;
    for (const auto &m : boards)
        a.append(QJsonObject{{"id", m.id}, {"name", m.name}, {"createdAt", m.createdAt}, {"updatedAt", m.updatedAt}, {"nodeCount", m.nodeCount}});
    return JsonFile::writeObject(m_path + "/boards/index.json", QJsonObject{{"boards", a}});
}

bool Vault::readBoard(const QString &id, BoardData *out) const {
    if (!BoardJson::safeId(id)) return false;
    QFile f(boardPath(id));
    if (!f.open(QIODevice::ReadOnly)) return false;
    QJsonParseError err;
    const auto doc = QJsonDocument::fromJson(f.readAll(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;
    *out = BoardJson::fromJson(doc.object());
    out->id = id;
    return true;
}

bool Vault::writeBoard(const BoardData &b) const {
    if (!BoardJson::safeId(b.id)) return false;
    if (!JsonFile::writeObject(boardPath(b.id), BoardJson::toJson(b), QJsonDocument::Indented)) return false;
    auto list = listBoards();
    bool found = false;
    for (auto &m : list)
        if (m.id == b.id) { m.name = b.name; m.updatedAt = b.updatedAt; m.nodeCount = b.nodes.size(); found = true; }
    if (!found) list.append({b.id, b.name, b.createdAt, b.updatedAt, int(b.nodes.size())});
    return writeIndex(list);
}

bool Vault::deleteBoard(const QString &id) const {
    if (!BoardJson::safeId(id)) return false;
    QFile::remove(boardPath(id));
    auto list = listBoards();
    list.removeIf([&](const BoardMeta &m) { return m.id == id; });
    return writeIndex(list);
}

BoardMeta Vault::createBoard(const QString &name) const {
    BoardData b;
    b.id = BoardJson::newId(); b.name = name;
    b.createdAt = b.updatedAt = BoardJson::nowIso();
    writeBoard(b);
    return {b.id, b.name, b.createdAt, b.updatedAt, 0};
}

QString Vault::resolve(const QString &rel) const {
    if (rel.isEmpty()) return {};
    const QString root = QDir(m_path).canonicalPath();
    const QString abs = QDir::cleanPath(root + "/" + rel);
    return abs.startsWith(root + "/") ? abs : QString();
}

static QString existingWithHash(const QString &dir, const QString &hash) {
    const auto hits = QDir(dir).entryList({hash + ".*"}, QDir::Files);
    for (const auto &h : hits) if (!h.contains("_thumb")) return h;
    return {};
}

ImportedFile Vault::importFile(const QString &src) const {
    ImportedFile r;
    QFile f(src);
    if (!f.open(QIODevice::ReadOnly)) { r.error = QStringLiteral("Could not read the file"); return r; }
    QCryptographicHash h(QCryptographicHash::Sha256);
    if (!h.addData(&f)) { r.error = QStringLiteral("Could not read the file"); return r; }
    f.close();
    return importBytes(src, QString::fromLatin1(h.result().toHex().left(16)), QFileInfo(src).fileName());
}

ImportedFile Vault::importBytes(const QString &src, const QString &hash, const QString &fileName) const {
    ImportedFile r;
    const QString dir = attachmentsDir();
    QDir().mkpath(dir);
    QString stored = existingWithHash(dir, hash);
    if (stored.isEmpty()) {
        stored = hash + "." + QFileInfo(src).suffix().toLower();
        if (!QFile::copy(src, dir + "/" + stored)) { r.error = QStringLiteral("Could not copy into the vault"); return r; }
    }
    const QString abs = dir + "/" + stored;
    const QString ext = QFileInfo(stored).suffix().toLower();
    const QString mime = QMimeDatabase().mimeTypeForFile(abs).name();
    r.relPath = "attachments/" + stored;
    r.fileName = fileName;
    r.mimeType = mime;
    r.fileSize = QFileInfo(abs).size();
    static const QStringList vids = {"mp4", "mov", "webm", "m4v", "mkv", "avi"};
    if (mime.startsWith("image/") && mime != "image/svg+xml") {
        r.nodeType = "image";
        const auto p = Mac::imageProps(abs);
        r.pixelW = p.w; r.pixelH = p.h;
        if (p.orientation >= 5 && p.orientation <= 8) std::swap(r.pixelW, r.pixelH);
    } else if (mime.startsWith("video/") || vids.contains(ext)) {
        r.nodeType = "video";
        const auto p = Mac::videoProps(abs);
        r.pixelW = p.w; r.pixelH = p.h;
        const QString thumbName = hash + "_thumb.png";
        if (!QFileInfo::exists(dir + "/" + thumbName)) {
            const QImage frame = Mac::videoFrame(abs, 720);
            if (!frame.isNull()) frame.save(dir + "/" + thumbName, "PNG");
        }
        if (QFileInfo::exists(dir + "/" + thumbName)) r.thumbRel = "attachments/" + thumbName;
    } else if (ext == "txt" || ext == "md" || ext == "markdown") {
        r.nodeType = "text";
        QFile tf(abs);
        if (tf.open(QIODevice::ReadOnly)) r.content = QString::fromUtf8(tf.read(180000)).left(60000);
    } else if (mime == "application/pdf" || ext == "pdf") {
        r.nodeType = "pdf";
    } else {
        r.nodeType = "file";
    }
    r.ok = true;
    return r;
}

ImportedFile Vault::importImage(const QImage &img) const {
    ImportedFile r;
    QByteArray png;
    QBuffer buf(&png);
    buf.open(QIODevice::WriteOnly);
    if (!img.save(&buf, "PNG")) { r.error = QStringLiteral("Could not encode the image"); return r; }
    const QString hash = QString::fromLatin1(QCryptographicHash::hash(png, QCryptographicHash::Sha256).toHex().left(16));
    QDir().mkpath(attachmentsDir());
    QString stored = existingWithHash(attachmentsDir(), hash);
    if (stored.isEmpty()) {
        stored = hash + ".png";
        QSaveFile f(attachmentsDir() + "/" + stored);
        if (!f.open(QIODevice::WriteOnly) || f.write(png) < 0 || !f.commit()) { r.error = QStringLiteral("Could not save the image"); return r; }
    }
    r.ok = true; r.nodeType = "image"; r.relPath = "attachments/" + stored;
    r.fileName = QStringLiteral("Pasted image.png"); r.mimeType = "image/png";
    r.fileSize = QFileInfo(attachmentsDir() + "/" + stored).size();
    r.pixelW = img.width(); r.pixelH = img.height();
    return r;
}
