#include "pdftext.h"
#include "videoitem.h"

#include <QCommandLineParser>
#include <QDir>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QStandardPaths>
#ifdef SORI_WEB_ENGINE
#include <QtWebEngineQuick/qtwebenginequickglobal.h>
#endif

#include <clocale>
#include <mpv/client.h>

extern "C" {
int sori_qt_start();
void sori_qt_stop();
void sori_qt_register_models();
}

namespace {
struct MpvLifetime {
    ~MpvLifetime() { sori_qt_stop(); }
};
}

int main(int argc, char **argv)
{
#ifdef Q_OS_LINUX
    // Let the desktop portal choose the system file dialog outside Sori's process.
    qputenv("QT_QPA_PLATFORMTHEME", "xdgdesktopportal");
    qputenv("QT_QPA_PLATFORMTHEME_QT6", "xdgdesktopportal");
#endif
#ifdef SORI_WEB_ENGINE
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QtWebEngineQuick::initialize();
    constexpr bool youtubeEmbeddingAvailable = true;
#else
    constexpr bool youtubeEmbeddingAvailable = false;
#endif
    // Keep fractional device scale factors instead of rounding them to whole
    // numbers. The zoom transform and PDF page rasterization then target the
    // real device pixel grid rather than one the compositor has to rescale.
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
    QGuiApplication app(argc, argv);
    // Qt initializes the system locale. libmpv requires C numeric formatting.
    std::setlocale(LC_NUMERIC, "C");
    app.setOrganizationName(QStringLiteral("Sori"));
    app.setApplicationName(QStringLiteral("Sori"));
    app.setDesktopFileName(QStringLiteral("com.sori.app"));
    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("A local-first Korean immersion app"));
    parser.addHelpOption();
    parser.addPositionalArgument("video", "Open a local video on launch.", "[video]");
    parser.process(app);
    if (parser.positionalArguments().size() > 1) parser.showHelp(2);

    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    // Distance-field glyphs scale cleanly with the zoom transform. Native text
    // rasterization looks pixelated there, and GPU curve rendering produced
    // broken pixels in small glyphs.
    QQuickWindow::setTextRenderType(QQuickWindow::QtTextRendering);
    QFontDatabase::addApplicationFont(":/assets/Inter-Variable.ttf");
    QFontDatabase::addApplicationFont(":/assets/NotoSansKR-Regular.otf");

    const auto result = sori_qt_start();
    if (result < 0) {
        qCritical("Could not start libmpv: %s", mpv_error_string(result));
        return 1;
    }
    const MpvLifetime mpv;
    RenderHost renderHost;
    PdfText pdfText;
    sori_qt_register_models();
    qmlRegisterType<VideoItem>("Sori", 1, 0, "VideoSurface");
    QQmlApplicationEngine engine;
    auto kiwiDirectory = app.applicationDirPath() + QStringLiteral("/kiwi");
    if (!QDir(kiwiDirectory).exists()) kiwiDirectory = QStringLiteral(SORI_KIWI_DIR);
    engine.setInitialProperties({{"renderHost", QVariant::fromValue(&renderHost)},
                                 {"pdfText", QVariant::fromValue(&pdfText)},
                                 {"dataDirectory", QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                                     + QStringLiteral("/com.sori.app")},
                                 {"kiwiDirectory", kiwiDirectory},
                                 {"startupPath", parser.positionalArguments().value(0)},
                                 {"youtubeEmbeddingAvailable", youtubeEmbeddingAvailable}});
    engine.load(QUrl("qrc:/qml/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
