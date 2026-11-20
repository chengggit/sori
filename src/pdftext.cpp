#include "pdftext.h"

#include <QPdfSelection>
#include <QRegularExpression>
#include <QVariantList>

PdfText::PdfText(QObject *parent)
    : QObject(parent)
{
}

bool PdfText::open(const QString &path)
{
    if (path.isEmpty())
        return false;
    if (path == m_path && m_document.status() == QPdfDocument::Status::Ready)
        return true;
    m_document.close();
    m_document.load(path);
    m_path = path;
    return m_document.status() == QPdfDocument::Status::Ready;
}

QVariantMap PdfText::page(int page)
{
    QVariantMap result;
    if (m_document.status() != QPdfDocument::Status::Ready
            || page < 0 || page >= m_document.pageCount())
        return result;

    const QPdfSelection all = m_document.getAllText(page);
    const QString text = all.text();
    QVariantList words;

    static const QRegularExpression pattern(QStringLiteral(
        "(?:[0-9][0-9,.]*)?[\\x{1100}-\\x{11ff}\\x{3131}-\\x{318e}"
        "\\x{a960}-\\x{a97c}\\x{ac00}-\\x{d7a3}\\x{d7b0}-\\x{d7c6}"
        "\\x{d7cb}-\\x{d7fb}]+"));

    auto matches = pattern.globalMatch(text);
    while (matches.hasNext()) {
        const auto match = matches.next();
        const QPdfSelection selection = m_document.getSelectionAtIndex(
            page, match.capturedStart(), match.capturedLength());
        if (!selection.isValid())
            continue;
        const QRectF rect = selection.boundingRectangle();
        if (rect.width() <= 0 || rect.height() <= 0)
            continue;

        QVariantMap word;
        word.insert("text", match.captured());
        word.insert("start", match.capturedStart());
        word.insert("end", match.capturedEnd());
        word.insert("x", rect.x());
        word.insert("y", rect.y());
        word.insert("width", rect.width());
        word.insert("height", rect.height());
        words.append(word);
    }

    result.insert("text", text);
    result.insert("words", words);
    return result;
}
