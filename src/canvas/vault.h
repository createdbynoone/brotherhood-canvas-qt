#pragma once
#include "boarddata.h"

#include <QImage>
#include <QString>
#include <QVector>

// A vault is a plain folder (Obsidian style): vault.json, boards/index.json, boards/<uuid>.json, attachments/.
// Everything here is synchronous file work, safe to call from a worker thread. Paths that come from JSON are
// resolved with `resolve`, which refuses anything outside the vault folder.
struct BoardMeta {
    QString id, name, createdAt, updatedAt;
    int nodeCount = 0;
};

struct ImportedFile {
    bool ok = false;
    QString error;
    QString nodeType;             // image | video | pdf | file
    QString relPath;              // attachments/<hash>.<ext>
    QString fileName, mimeType;
    qint64 fileSize = 0;
    QString thumbRel;             // video poster, attachments/<hash>_thumb.png
    QString content;              // text / markdown files: their first 60000 characters
    int pixelW = 0, pixelH = 0;   // natural size (images, videos)
};

class Vault {
public:
    Vault() = default;
    explicit Vault(const QString &path) : m_path(path) {}

    static bool isVault(const QString &path);
    static bool create(const QString &path, const QString &name, QString *error = nullptr);

    QString path() const { return m_path; }
    bool valid() const { return !m_path.isEmpty() && isVault(m_path); }
    QString name() const;

    QVector<BoardMeta> listBoards() const;
    bool writeIndex(const QVector<BoardMeta> &boards) const;
    bool readBoard(const QString &id, BoardData *out) const;
    bool writeBoard(const BoardData &b) const;               // also refreshes the index entry
    bool deleteBoard(const QString &id) const;
    BoardMeta createBoard(const QString &name) const;       // empty board + index entry

    ImportedFile importFile(const QString &src) const;       // dedupes by SHA-256 (first 16 hex)
    ImportedFile importImage(const QImage &img) const;       // e.g. a pasted screenshot, stored as PNG
    QString resolve(const QString &rel) const;               // absolute path, or empty when outside the vault
    QString attachmentsDir() const { return m_path + "/attachments"; }

private:
    QString boardPath(const QString &id) const { return m_path + "/boards/" + id + ".json"; }
    ImportedFile importBytes(const QString &src, const QString &hash, const QString &fileName) const;
    QString m_path;
};
