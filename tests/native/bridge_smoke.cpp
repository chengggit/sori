#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QFile>
#include <QElapsedTimer>
#include <QThread>
#include <QDebug>
#include <clocale>
#include <cstdio>

extern "C" void sori_qt_register_models();

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");
    app.setOrganizationName("SoriTests");
    app.setApplicationName("BridgeContract");
    QTemporaryDir directory;
    if (!directory.isValid()) return 1;
    QFile env(directory.path() + "/empty.env");
    if (!env.open(QIODevice::WriteOnly)) return 1;
    env.close();
    qputenv("SORI_ENV_FILE", env.fileName().toUtf8());
    qunsetenv("SORI_YOUTUBE_API_KEY");
    sori_qt_register_models();
    QQmlEngine engine;
    engine.rootContext()->setContextProperty("testDirectory", directory.path());
    QQmlComponent component(&engine);
    component.setData(R"QML(
import QtQml
import sori_core
QtObject {
    id: test
    property string failure: ""
    property int completed: 0
    function check(reply, expectedOk) {
        if (!reply || reply.ok !== expectedOk || typeof reply.error !== "string"
                || !Object.prototype.hasOwnProperty.call(reply, "data") || (reply.ok && reply.error !== "")
                || (!reply.ok && (!reply.error || reply.data !== null)))
            throw new Error("Invalid response: " + JSON.stringify(reply))
        return reply.data
    }
    function expect(condition, message) { if (!condition) throw new Error(message) }
    function completion(reply) {
        try { check(reply, false); completed++ }
        catch (error) { failure = error.toString() }
    }
    property Connections analysisConnection: Connections {
        target: Analysis
        function onFinished(request, reply) { test.completion(reply) }
        function onPassageFinished(request, reply) { test.completion(reply) }
        function onDictionaryFinished(request, reply) { test.completion(reply) }
    }
    property Connections libraryConnection: Connections {
        target: Library
        function onBackgroundFinished(job, key, reply) {
            try {
                test.check(reply, false)
                test.expect(Library.error !== "", "Background error must remain observable")
                test.completed++
            } catch (error) { test.failure = error.toString() }
        }
    }
    property Connections youtubeConnection: Connections {
        target: YouTube
        function onChannelResolved(request, reply) { test.completion(reply) }
    }
    Component.onCompleted: {
        try {
            check(Library.initialize(testDirectory), true)
            expect(check(Library.addDocument("Book", "학교에 가요."), true) === null, "Mutation must return null data")
            const id = Library.documents[0].id
            expect(check(Library.readDocument(id), true).content === "학교에 가요.", "Read changed document data")
            check(Library.readDocument(-1), false)
            expect(check(Library.ensureVideoThumbnail(-1), true) === true, "Missing job acknowledgement")
            check(Library.saveReadingProgress(id, 0.5), true)
            check(Library.saveReadingProgress(id, -1), false)
            expect(check(Library.findWord("document", id, "학교", "학교에 가요."), true) === null, "Absent lookup must succeed with null")
            const draft = {word:"학교", normalizedForm:null, context:"학교에 가요.", definition:null, tags:[]}
            const saved = check(Library.saveWord("document", id, draft), true)
            expect(check(Library.findWord("document", id, "학교", "학교에 가요."), true).id === saved.id, "Find must return saved entry")
            check(Library.saveWord("typo", id, draft), false)
            check(Library.editWord(saved.id, {normalizedForm:"학교",meaning:"school",note:"",tags:[]}), true)
            check(Library.removeWord(saved.id), true)
            check(Library.removeDocument(id), true)
            check(Analysis.initializeDictionary(testDirectory), true)
            check(Analysis.saveKrdictKey("invalid"), false)
            check(Analysis.setDefaultDictionary("invalid"), false)
            check(Analysis.dictionaryLookupUrl("https://example.test/?q={word}", "test"), true)
            check(Analysis.dictionaryLookupUrl("file:///invalid", "test"), false)
            check(YouTube.initialize(testDirectory), true)
            check(YouTube.saveApiKey("invalid!"), false)
            check(YouTube.resolveLink("https://youtu.be/dQw4w9WgXcQ"), true)
            check(YouTube.resolveLink("invalid"), false)
            Analysis.initialize(testDirectory + "/missing-kiwi")
            expect(Analysis.analyze("학교에 가요.", 0, 2) > 0, "Missing analysis request ID")
            expect(Analysis.tokenizePassage("학교에 가요.") > 0, "Missing passage request ID")
            expect(Analysis.lookupDictionary("") > 0, "Missing dictionary request ID")
            expect(YouTube.resolveChannel("@test") > 0, "Missing channel request ID")
        } catch (error) { failure = error.toString() }
    }
}
)QML", QUrl("file:///bridge-contract.qml"));
    auto *root = component.create();
    if (!root) { for (const auto &error : component.errors()) std::fprintf(stderr, "%s\n", qPrintable(error.toString())); return 2; }
    QElapsedTimer timer;
    timer.start();
    while (root->property("failure").toString().isEmpty()
           && root->property("completed").toInt() < 5 && timer.elapsed() < 10000) {
        app.processEvents();
        QThread::msleep(5);
    }
    const auto failure = root->property("failure").toString();
    const bool passed = failure.isEmpty() && root->property("completed").toInt() == 5;
    if (!passed) std::fprintf(stderr, "Bridge contract failed: %s; completions: %d\n", qPrintable(failure), root->property("completed").toInt());
    delete root;
    return passed ? 0 : 3;
}
