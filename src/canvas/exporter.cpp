#include "exporter.h"

#include "edgemodel.h"
#include "../platform/mac.h"

#include <QDir>
#include <QFileInfo>
#include <QPageSize>
#include <QPainter>
#include <QPainterPath>
#include <QPdfWriter>
#include <QTextDocument>
#include <QAbstractTextDocumentLayout>
#include <QtMath>

namespace {

const QColor kBg("#0B0B0A"), kSurface("#111110"), kRaised("#171716"), kText("#ECE8DF"), kTextDim("#A19F98"), kAccent("#F54F1B");

struct Ctx {
    QString root, brand;
    double scale;       // device pixels per world unit (for choosing image resolution)
};

QString abs(const Ctx &c, const QString &rel) {
    if (rel.isEmpty()) return {};
    const QString base = QDir(c.root).canonicalPath(), a = QDir::cleanPath(base + "/" + rel);
    return a.startsWith(base + "/") ? a : QString();
}

QFont uiFont(double px, int weight = QFont::Normal) {
    QFont f("Geist");
    f.setPixelSize(qMax(1, int(qRound(px))));
    f.setWeight(QFont::Weight(weight));
    return f;
}

void drawCover(QPainter &p, const QRectF &target, const QImage &img) {
    if (img.isNull() || target.isEmpty()) return;
    const double ta = target.width() / target.height(), ia = double(img.width()) / img.height();
    QRectF src(0, 0, img.width(), img.height());
    if (ia > ta) { const double w = img.height() * ta; src = QRectF((img.width() - w) / 2, 0, w, img.height()); }
    else { const double h = img.width() / ta; src = QRectF(0, (img.height() - h) / 2, img.width(), h); }
    p.drawImage(target, img, src);
}

void drawMarkdown(QPainter &p, const QRectF &r, const QString &md, const QColor &color, double basePx) {
    QTextDocument doc;
    QFont f = uiFont(basePx);
    doc.setDefaultFont(f);
    doc.setMarkdown(md);
    doc.setDocumentMargin(0);
    doc.setTextWidth(r.width());
    QAbstractTextDocumentLayout::PaintContext pc;
    pc.palette.setColor(QPalette::Text, color);
    pc.clip = QRectF(0, 0, r.width(), r.height());
    p.save();
    p.translate(r.topLeft());
    p.setClipRect(QRectF(0, 0, r.width(), r.height()));
    doc.documentLayout()->draw(&p, pc);
    p.restore();
}

void drawNode(QPainter &p, const NodeData &n, const Ctx &c) {
    const QRectF r(n.x, n.y, n.w, n.h);
    const QJsonObject st = n.data.value("nodeStyle").toObject();
    const double radius = st.contains("borderRadius") ? st["borderRadius"].toDouble() : (n.type == "note" ? 14 : 12);
    const double opacity = st.contains("opacity") ? st["opacity"].toDouble() : 1.0;
    const QString noteColor = n.data.value("noteColor").toString("#F54F1B");
    QColor border = st.contains("borderColor") ? QColor(st["borderColor"].toString()) : QColor(255, 255, 255, 36);
    if (n.type == "note" && !st.contains("borderColor")) { border = QColor(noteColor); border.setAlphaF(0.35); }
    const double bw = st.contains("borderWidth") ? st["borderWidth"].toDouble() : 1.0;
    p.save();
    p.setOpacity(opacity);
    QPainterPath clip;
    clip.addRoundedRect(r, radius, radius);

    if (n.type == "title") {
        p.restore();
        p.save();
        const QString text = n.data.value("content").toString();
        QFont f(c.brand.isEmpty() ? "Geist" : c.brand);
        if (c.brand.isEmpty()) f.setWeight(QFont::Bold);
        f.setPixelSize(n.data.value("fontSize").toInt(32));
        f.setCapitalization(QFont::AllUppercase);
        p.setFont(f); p.setPen(kText);
        p.drawText(r, Qt::AlignCenter | Qt::TextWordWrap, text);
        p.restore();
        return;
    }

    // body
    QColor bg = st.contains("backgroundColor") ? QColor(st["backgroundColor"].toString()) : (n.type == "note" ? QColor(23, 23, 22, 235) : kSurface);
    if (n.type == "image" && !st.contains("backgroundColor")) bg = Qt::transparent;
    p.setPen(Qt::NoPen);
    p.setBrush(bg);
    p.drawPath(clip);
    p.setClipPath(clip);

    const QString label = n.data.value("label").toString();
    const double strip = (!label.isEmpty() && n.type != "note") ? 24 : 0;
    const QRectF body = r.adjusted(0, 0, 0, -strip);

    if (n.type == "image") {
        const int px = qBound(64, int(qMax(n.w, n.h) * c.scale * 1.0), 4096);
        drawCover(p, body, Mac::downsample(abs(c, n.data.value("filePath").toString()), px));
    } else if (n.type == "video") {
        const int px = qBound(64, int(qMax(n.w, n.h) * c.scale), 2048);
        QString thumb = abs(c, n.data.value("thumbnailPath").toString());
        QImage img = thumb.isEmpty() ? Mac::videoFrame(abs(c, n.data.value("filePath").toString()), px) : Mac::downsample(thumb, px);
        drawCover(p, body, img);
        const double rr = qBound(14.0, qMin(body.width(), body.height()) * 0.12, 30.0);
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(11, 11, 10, 160));
        p.drawEllipse(body.center(), rr, rr);
        QPainterPath tri;
        const QPointF m = body.center();
        tri.moveTo(m.x() - rr * 0.28, m.y() - rr * 0.42); tri.lineTo(m.x() + rr * 0.46, m.y()); tri.lineTo(m.x() - rr * 0.28, m.y() + rr * 0.42); tri.closeSubpath();
        p.setBrush(kText);
        p.drawPath(tri);
    } else if (n.type == "pdf" || n.type == "file") {
        const QRectF pageArea = body.adjusted(0, 0, 0, -44);
        if (n.type == "pdf") {
            QImage page = Mac::pdfPage(abs(c, n.data.value("filePath").toString()), qBound(128, int(qMax(n.w, n.h) * c.scale), 2048));
            if (!page.isNull()) {
                const double sc = pageArea.width() / page.width();
                const QRectF dst(pageArea.left(), pageArea.top(), pageArea.width(), qMin(pageArea.height(), page.height() * sc));
                p.drawImage(dst, page, QRectF(0, 0, page.width(), dst.height() / sc));
            }
        }
        p.setPen(kText);
        p.setFont(uiFont(12, QFont::Medium));
        p.drawText(QRectF(body.left() + 12, body.bottom() - 40, body.width() - 24, 20), Qt::AlignLeft | Qt::AlignVCenter, QFontMetricsF(uiFont(12, QFont::Medium)).elidedText(n.data.value("fileName").toString(), Qt::ElideMiddle, body.width() - 24));
    } else {            // text, note
        QRectF inner = body.adjusted(14, 12, -14, -12);
        if (n.type == "note") {
            p.setPen(Qt::NoPen); p.setBrush(QColor(noteColor));
            p.drawRect(QRectF(r.left(), r.top(), r.width(), 3));
            inner = body.adjusted(14, 15, -14, -12);
        }
        drawMarkdown(p, inner, n.data.value("content").toString(), kText, 13);
    }
    if (strip > 0) {
        p.setPen(Qt::NoPen); p.setBrush(QColor(11, 11, 10, 217));
        p.drawRect(QRectF(r.left(), r.bottom() - strip, r.width(), strip));
        QFont f(c.brand.isEmpty() ? "Geist" : c.brand);
        f.setPixelSize(10); f.setCapitalization(QFont::AllUppercase);
        if (c.brand.isEmpty()) f.setWeight(QFont::Bold);
        p.setFont(f); p.setPen(kTextDim);
        p.drawText(QRectF(r.left() + 10, r.bottom() - strip, r.width() - 20, strip), Qt::AlignLeft | Qt::AlignVCenter, label);
    }
    p.setClipping(false);
    if (bw > 0) {
        p.setBrush(Qt::NoBrush);
        p.setPen(QPen(border, bw));
        p.drawRoundedRect(r.adjusted(bw / 2, bw / 2, -bw / 2, -bw / 2), radius, radius);
    }
    p.restore();
}

void drawEdge(QPainter &p, const EdgeData &e, const QHash<QString, QRectF> &rects) {
    if (!rects.contains(e.source) || !rects.contains(e.target)) return;
    const QPointF p1 = EdgeModel::anchor(rects[e.source], e.sourceHandle), p2 = EdgeModel::anchor(rects[e.target], e.targetHandle);
    QPointF c1, c2;
    EdgeModel::controlPoints(p1, e.sourceHandle, p2, e.targetHandle, &c1, &c2);
    QColor col = e.data.contains("color") ? QColor(e.data["color"].toString()) : QColor(255, 255, 255, 80);
    const double w = e.data.value("strokeWidth").toDouble(1.5);
    QPen pen(col, w);
    pen.setCapStyle(Qt::RoundCap);
    if (e.data.value("dashed").toBool() || e.data.value("animated").toBool()) pen.setStyle(Qt::DashLine);
    QPainterPath path(p1);
    path.cubicTo(c1, c2, p2);
    p.setPen(pen); p.setBrush(Qt::NoBrush);
    p.drawPath(path);
    const auto head = [&](const QPointF &tip, QPointF d, const QPointF &fallback) {
        if (d.manhattanLength() < 0.01) d = fallback;
        const double a = qAtan2(d.y(), d.x()), s = 7 + w * 1.6;
        QPainterPath tri;
        tri.moveTo(tip);
        tri.lineTo(tip - QPointF(qCos(a - 0.45), qSin(a - 0.45)) * s);
        tri.lineTo(tip - QPointF(qCos(a) , qSin(a)) * (s * 0.78));
        tri.lineTo(tip - QPointF(qCos(a + 0.45), qSin(a + 0.45)) * s);
        tri.closeSubpath();
        p.setPen(Qt::NoPen); p.setBrush(col);
        p.drawPath(tri);
    };
    if (e.data.value("arrow").toBool(true)) head(p2, p2 - c2, p2 - p1);
    if (e.data.value("arrowStart").toBool(false)) head(p1, p1 - c1, p1 - p2);
    if (!e.label.isEmpty()) {
        const QPointF m = EdgeModel::bezier(p1, c1, c2, p2, 0.5);
        p.setFont(uiFont(11, QFont::Medium));
        const QRectF tr = QFontMetricsF(p.font()).boundingRect(e.label).adjusted(-8, -4, 8, 4);
        const QRectF box(m.x() - tr.width() / 2, m.y() - tr.height() / 2, tr.width(), tr.height());
        p.setPen(QPen(QColor(255, 255, 255, 36), 1)); p.setBrush(kRaised);
        p.drawRoundedRect(box, 8, 8);
        p.setPen(kText);
        p.drawText(box, Qt::AlignCenter, e.label);
    }
}

void paintAll(QPainter &p, const QVector<NodeData> &nodes, const QVector<EdgeData> &edges, const Ctx &c) {
    QHash<QString, QRectF> rects;
    for (const auto &n : nodes) rects.insert(n.id, QRectF(n.x, n.y, n.w, n.h));
    p.setRenderHints(QPainter::Antialiasing | QPainter::TextAntialiasing | QPainter::SmoothPixmapTransform);
    for (const auto &e : edges) drawEdge(p, e, rects);
    for (const auto &n : nodes) drawNode(p, n, c);
}

}  // namespace

namespace Exporter {

QString render(const BoardData &board, const QSet<QString> &only, const QString &vaultRoot, const QString &outPath, const QString &brandFamily) {
    QVector<NodeData> nodes;
    for (const auto &n : board.nodes) if (only.isEmpty() || only.contains(n.id)) nodes.append(n);
    if (nodes.isEmpty()) return QStringLiteral("There is nothing to export");
    QVector<EdgeData> edges;
    QSet<QString> ids;
    for (const auto &n : nodes) ids.insert(n.id);
    for (const auto &e : board.edges) if (ids.contains(e.source) && ids.contains(e.target)) edges.append(e);

    QRectF box;
    for (const auto &n : nodes) box = box.isNull() ? QRectF(n.x, n.y, n.w, n.h) : box.united(QRectF(n.x, n.y, n.w, n.h));
    const double pad = 64;
    box.adjust(-pad, -pad, pad, pad);

    const bool pdf = outPath.endsWith(".pdf", Qt::CaseInsensitive);
    if (pdf) {
        QPdfWriter w(outPath);
        w.setResolution(72);
        w.setPageSize(QPageSize(QSizeF(box.width(), box.height()), QPageSize::Point));
        w.setPageMargins(QMarginsF(0, 0, 0, 0));
        w.setTitle(board.name);
        QPainter p(&w);
        if (!p.isActive()) return QStringLiteral("Could not create the PDF");
        p.fillRect(QRectF(0, 0, box.width(), box.height()), kBg);
        p.translate(-box.topLeft());
        paintAll(p, nodes, edges, {vaultRoot, brandFamily, 2.0});
        p.end();
        return {};
    }
    // PNG / JPG: 2x unless that would exceed ~6k px on the long side (opaque RGB keeps the file a sane size)
    const double scale = qMin(2.0, 6144.0 / qMax(box.width(), box.height()));
    QImage img(qMax(1, int(box.width() * scale)), qMax(1, int(box.height() * scale)), QImage::Format_RGB32);
    if (img.isNull()) return QStringLiteral("The board is too large to export as an image");
    img.fill(kBg);
    QPainter p(&img);
    p.scale(scale, scale);
    p.translate(-box.topLeft());
    paintAll(p, nodes, edges, {vaultRoot, brandFamily, scale});
    p.end();
    if (!img.save(outPath, outPath.endsWith(".jpg", Qt::CaseInsensitive) ? "JPG" : "PNG", 95)) return QStringLiteral("Could not write the image");
    return {};
}

}  // namespace Exporter
