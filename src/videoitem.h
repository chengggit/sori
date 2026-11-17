#pragma once

#include <QQuickFramebufferObject>
#include <QUrl>
#include <atomic>

class QQuickTextDocument;

class RenderHost : public QObject
{
    Q_OBJECT
public:
    RenderHost();
    Q_INVOKABLE QString localPath(const QUrl &url) const { return url.toLocalFile(); }
    Q_INVOKABLE void checkFrame();
    Q_INVOKABLE void setReadingLineHeight(QQuickTextDocument *document, int pixels);
    void frameRendered();

    void *nativeDisplay = nullptr;
    unsigned displayParameter = 0;

signals:
    void frameRequested();
    void rendererReady(bool ready);
    void rendererFailed(int result);

private:
    std::atomic<qint64> lastRendered{0};
};

class VideoItem : public QQuickFramebufferObject
{
    Q_OBJECT
    Q_PROPERTY(RenderHost *host READ host WRITE setHost NOTIFY hostChanged)
public:
    explicit VideoItem(QQuickItem *parent = nullptr);
    RenderHost *host() const { return source; }
    void setHost(RenderHost *host);
    Renderer *createRenderer() const override;

signals:
    void hostChanged();

private:
    RenderHost *source = nullptr;
};
