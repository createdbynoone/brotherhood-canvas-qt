#pragma once
#include "boardmodel.h"
#include "boardsmodel.h"
#include "vault.h"

#include <QObject>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>

// Vault and board lifecycle: opening a vault, switching / creating / renaming boards, autosave, file imports,
// the clipboard and export. The open board itself lives in BoardModel.
class CanvasController : public QObject {
    Q_OBJECT
    Q_PROPERTY(BoardModel *board READ board CONSTANT)
    Q_PROPERTY(BoardsModel *boards READ boards CONSTANT)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)                   // "welcome" | "ready"
    Q_PROPERTY(QString message READ message NOTIFY stateChanged)               // why the welcome screen is showing
    Q_PROPERTY(QString vaultPath READ vaultPath NOTIFY vaultChanged)
    Q_PROPERTY(QString vaultName READ vaultName NOTIFY vaultChanged)
    Q_PROPERTY(QString currentBoardId READ currentBoardId NOTIFY currentChanged)
    Q_PROPERTY(int importing READ importing NOTIFY importingChanged)           // files still being copied in
    Q_PROPERTY(bool exporting READ exporting NOTIFY exportingChanged)

public:
    explicit CanvasController(QObject *parent = nullptr);

    BoardModel *board() { return &m_board; }
    BoardsModel *boards() { return &m_boards; }
    QString state() const { return m_state; }
    QString message() const { return m_message; }
    QString vaultPath() const { return m_vault.path(); }
    QString vaultName() const { return m_vault.valid() ? m_vault.name() : QString(); }
    QString currentBoardId() const { return m_board.boardId(); }
    int importing() const { return m_importing; }
    bool exporting() const { return m_exporting; }

    void start();                                   // open the last vault, or show the welcome screen
    void flush();                                   // write everything pending (on quit)

    Q_INVOKABLE bool openVault(const QString &path);
    Q_INVOKABLE bool createVault(const QString &path);
    Q_INVOKABLE void closeVault();
    Q_INVOKABLE void openBoard(const QString &id);
    Q_INVOKABLE QString newBoard();
    Q_INVOKABLE void renameBoard(const QString &id, const QString &name);
    Q_INVOKABLE void deleteBoard(const QString &id);
    Q_INVOKABLE void moveBoard(int from, int to);
    Q_INVOKABLE void saveSoon();
    Q_INVOKABLE void saveNow();

    Q_INVOKABLE void copySelection();
    Q_INVOKABLE void cutSelection();
    Q_INVOKABLE void paste(double wx, double wy);
    Q_INVOKABLE bool canPaste() const;
    Q_INVOKABLE void importUrls(const QList<QUrl> &urls, double wx, double wy);
    Q_INVOKABLE void addText(double wx, double wy, const QString &type);       // text | note | title
    Q_INVOKABLE void revealNode(const QString &id);
    Q_INVOKABLE void openNodeFile(const QString &id);
    Q_INVOKABLE void exportBoard(const QUrl &file, bool selectionOnly);

signals:
    void stateChanged();
    void vaultChanged();
    void currentChanged();
    void importingChanged();
    void exportingChanged();
    void toast(const QString &message, int kind);
    void placed(const QRectF &worldRect);           // where new content landed (QML may want to reveal it)

private:
    void setState(const QString &s, const QString &msg = {});
    void loadBoard(const QString &id);
    void afterVaultOpened();
    void importPaths(const QStringList &paths, double wx, double wy);
    void placeImported(const QString &boardId, const QVector<ImportedFile> &files, double wx, double wy);
    QString nextBoardName() const;
    void persistIndex();

    BoardModel m_board;
    BoardsModel m_boards;
    Vault m_vault;
    QString m_state = "welcome", m_message;
    QTimer m_saveTimer, m_viewTimer;
    QThreadPool m_io, m_work;
    int m_importing = 0, m_pasteRepeat = 0;
    bool m_exporting = false, m_loading = false;
    QString m_lastPasteMarker;
};
