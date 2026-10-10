// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT

// Loads the plugin settings page (configui.qml) through a real QQmlEngine so
// a broken page is caught by ctest instead of only inside the digital clock
// settings dialog. The local qmllint build silently mis-checks files, so this
// probe is the authoritative syntax/property check for the page.
//
// Usage: probe_configui [path-to-configui.qml]
// Exits 0 when the page is ready and instantiable; 1 with the QML errors.

#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QElapsedTimer>
#include <QUrl>

#include <cstdio>

int main(int argc, char *argv[])
{
    // The page pulls in Kirigami/KCM visual types: a plain QCoreApplication
    // segfaults inside the QML type initialization.
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QGuiApplication app(argc, argv);

    const QString pagePath = argc > 1
        ? QString::fromLocal8Bit(argv[1])
        : QStringLiteral(CONFIGUI_PATH);

    QQmlEngine engine;
    // The page imports the config helper module; system QML import paths
    // provide it (installed alongside the plugin). Keep the source tree import
    // path last so a stale built copy never masks the file under test.
    engine.addImportPath(QStringLiteral("/usr/lib/qt6/qml"));

    QQmlComponent component(&engine, QUrl::fromLocalFile(pagePath));
    QElapsedTimer timer;
    timer.start();
    while (component.isLoading() && timer.elapsed() < 8000) {
        QCoreApplication::processEvents();
    }
    if (!component.isReady()) {
        std::fprintf(stderr, "PROBE FAILED: %s is not loadable\n",
                     qUtf8Printable(pagePath));
        const auto errors = component.errors();
        for (const QQmlError &error : errors) {
            std::fprintf(stderr, "  %s\n", qUtf8Printable(error.toString()));
        }
        return 1;
    }

    QObject *page = component.create();
    if (page == nullptr) {
        std::fprintf(stderr, "PROBE FAILED: %s created no object\n",
                     qUtf8Printable(pagePath));
        return 1;
    }
    delete page;

    std::printf("PROBE OK configui\n");
    return 0;
}
