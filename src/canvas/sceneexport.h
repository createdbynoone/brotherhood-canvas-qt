#pragma once
#include <QImage>
#include <QObject>
#include <QRectF>
#include <QStringList>
#include <QTimer>

class QQmlEngine;
class QQuickView;
class BoardModel;

// Exports a board by drawing the real scene (qml/canvas/ExportScene.qml: the same NodeItem / EdgeItem the app shows) in a
// private QML engine and an invisible window, then grabbing that window. So the export is what the screen shows,
// fonts, arrows, sticky notes and all, instead of a second renderer that has to be kept in step by hand.
class SceneExport : public QObject {
    Q_OBJECT
public:
    struct Params {
        BoardModel *board = nullptr;
        QObject *app = nullptr;
        QString out;                       // .png, .jpg or .pdf
        QRectF box;                        // world rectangle, padding included
        QStringList only, onlyEdges;       // empty = everything
        QString pattern, brand, marker;
    };
    SceneExport(const Params &p, QObject *parent = nullptr);
    ~SceneExport() override;
    /// False when the scene could not be built (the caller can fall back to the old painter).
    bool start(QString *error);

signals:
    void finished(const QString &error);   // empty = written

private:
    void poll();
    void grabAndSave();
    Params m_p;
    QQmlEngine *m_engine = nullptr;
    QQuickView *m_view = nullptr;
    QTimer m_timer;
    int m_ticks = 0, m_calm = 0;
    double m_scale = 1, m_target = 1;
};
