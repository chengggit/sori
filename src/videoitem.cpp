#include "videoitem.h"

#include <QGuiApplication>
#include <QtGui/qguiapplication_platform.h>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QQuickOpenGLUtils>
#include <mpv/render.h>
#include <chrono>

extern "C" {
mpv_handle *sori_qt_handle();
int sori_mpv_renderer_create(mpv_render_context **context, mpv_handle *handle,
                             void *(*resolve)(void *, const char *),
                             mpv_render_param_type displayKind, void *display,
                             mpv_render_update_fn requestFrame, void *callbackData);
int sori_mpv_renderer_draw(mpv_render_context *context, int framebuffer,
                           int width, int height, int format);
void sori_mpv_renderer_free(mpv_render_context *context);
}

namespace {
qint64 monotonicMs()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

void *resolveOpenGL(void *, const char *name)
{
    return reinterpret_cast<void *>(QOpenGLContext::currentContext()->getProcAddress(name));
}

class VideoRenderer : public QQuickFramebufferObject::Renderer
{
public:
    ~VideoRenderer() override
    {
        if (!context) return;
        sori_mpv_renderer_free(context);
        QMetaObject::invokeMethod(host, [source = host] {
            emit source->rendererReady(false);
        }, Qt::QueuedConnection);
    }

    void synchronize(QQuickFramebufferObject *item) override
    {
        host = static_cast<VideoItem *>(item)->host();
    }

    void render() override
    {
        if (!host || !sori_qt_handle()) return;
        if (!context && !initialize()) return;

        auto *fbo = framebufferObject();
        const int result = sori_mpv_renderer_draw(
            context, static_cast<int>(fbo->handle()), fbo->width(), fbo->height(), GL_RGBA8);
        if (result < 0 && !failed) {
            failed = true;
            QMetaObject::invokeMethod(host, [source = host, result] {
                emit source->rendererFailed(result);
            }, Qt::QueuedConnection);
        }
        host->frameRendered();
        QQuickOpenGLUtils::resetOpenGLState();
    }

private:
    bool initialize()
    {
        if (failed) return false;
        // The render host outlives the QML engine and its render nodes.
        const int result = sori_mpv_renderer_create(
            &context, sori_qt_handle(), resolveOpenGL,
            static_cast<mpv_render_param_type>(host->displayParameter), host->nativeDisplay,
            [](void *data) {
                auto *source = static_cast<RenderHost *>(data);
                QMetaObject::invokeMethod(source, &RenderHost::frameRequested, Qt::QueuedConnection);
            }, host);
        if (result < 0) {
            failed = true;
            QMetaObject::invokeMethod(host, [source = host, result] {
                emit source->rendererFailed(result);
            }, Qt::QueuedConnection);
            return false;
        }

        QMetaObject::invokeMethod(host, [source = host] {
            emit source->rendererReady(true);
        }, Qt::QueuedConnection);
        return true;
    }

    RenderHost *host = nullptr;
    mpv_render_context *context = nullptr;
    bool failed = false;
};
}

RenderHost::RenderHost()
{
#if QT_CONFIG(wayland)
    if (const auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>()) {
        nativeDisplay = wayland->display();
        displayParameter = MPV_RENDER_PARAM_WL_DISPLAY;
    }
#endif
#if QT_CONFIG(xcb)
    if (const auto *x11 = qGuiApp->nativeInterface<QNativeInterface::QX11Application>()) {
        nativeDisplay = x11->display();
        displayParameter = MPV_RENDER_PARAM_X11_DISPLAY;
    }
#endif
}

void RenderHost::frameRendered()
{
    lastRendered.store(monotonicMs(), std::memory_order_relaxed);
}

void RenderHost::checkFrame()
{
    if (monotonicMs() - lastRendered.load(std::memory_order_relaxed) > 20) emit frameRequested();
}

VideoItem::VideoItem(QQuickItem *parent) : QQuickFramebufferObject(parent)
{
    // mpv writes into an FBO with a top-left image origin. Qt's default texture orientation matches it.
    setMirrorVertically(false);
}

void VideoItem::setHost(RenderHost *host)
{
    if (source == host) return;
    if (source) disconnect(source, nullptr, this, nullptr);
    source = host;
    if (source) {
        connect(source, &RenderHost::frameRequested, this, [this] { update(); });
    }
    emit hostChanged();
    update();
}

QQuickFramebufferObject::Renderer *VideoItem::createRenderer() const
{
    return new VideoRenderer;
}
