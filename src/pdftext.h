#pragma once

#include <QObject>
#include <QPdfDocument>
#include <QVariantMap>

class PdfText : public QObject
{
    Q_OBJECT
public:
    explicit PdfText(QObject *parent = nullptr);

    Q_INVOKABLE bool open(const QString &path);
    Q_INVOKABLE QVariantMap page(int page);

private:
    QPdfDocument m_document;
    QString m_path;
};
