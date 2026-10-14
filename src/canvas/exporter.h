#pragma once
#include "boarddata.h"

#include <QSet>
#include <QString>

// Renders a board (or just a selection) to PNG, JPEG or vector PDF with QPainter, independent of what is on screen.
// Called from a worker thread; the drawing mirrors the on-screen node designs.
namespace Exporter {
QString render(const BoardData &board, const QSet<QString> &only, const QString &vaultRoot, const QString &outPath,
               const QString &brandFamily);                  // returns an error message, or empty on success
}
