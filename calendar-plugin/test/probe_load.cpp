// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT

// Out-of-process probe for the built weatherevents plugin.
//
// Verifies, in order:
//   1. QPluginLoader::metaData() reports KPlugin.Id == "weatherevents";
//   2. KPluginMetaData built from the plugin file is valid and has a name;
//   3. the .so actually loads;
//   4. the instance qobject_casts to CalendarEvents::CalendarEventsPlugin;
//   5. loadEventsForDateRange(today, today) emits dataReady; with no
//      location configured (the probe isolates XDG_CONFIG_HOME/XDG_CACHE_HOME
//      in a fresh temp dir) the set is empty and no fetch is attempted.
//
// Usage: probe_load <path-to-plugin-.so>
// Prints "PROBE OK events=N" and exits 0 on success; prints a precise
// failure reason and exits 1 otherwise.

#include <KPluginMetaData>

#include <QCoreApplication>
#include <QDate>
#include <QDir>
#include <QEventLoop>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPluginLoader>
#include <QTemporaryDir>
#include <QTimer>

#include <CalendarEvents/CalendarEventsPlugin>

#include <cstdio>

int main(int argc, char *argv[])
{
    // Isolate from the user's real config and cache BEFORE anything resolves
    // XDG paths: the probe must be deterministic and must never trigger a
    // network fetch or touch ~/.config/weathereventsrc / the real cache.
    QTemporaryDir scratchDir(QDir::tempPath() + QLatin1String("/weatherevents-probe-load-XXXXXX"));
    if (!scratchDir.isValid()) {
        std::fprintf(stderr, "PROBE FAILED: cannot create a scratch dir in %s\n",
                     qUtf8Printable(QDir::tempPath()));
        return 1;
    }
    qputenv("XDG_CONFIG_HOME", QFile::encodeName(scratchDir.path() + QLatin1String("/config")));
    qputenv("XDG_CACHE_HOME", QFile::encodeName(scratchDir.path() + QLatin1String("/cache")));

    QCoreApplication app(argc, argv);

    if (argc != 2) {
        std::fprintf(stderr, "Usage: probe_load <path-to-plugin-.so>\n");
        return 1;
    }
    // QPluginLoader does not resolve relative paths against the caller's
    // cwd on all platforms, so normalize before use.
    const QString pluginPath =
        QFileInfo(QDir::current().absoluteFilePath(QString::fromLocal8Bit(argv[1])))
            .absoluteFilePath();

    QPluginLoader loader(pluginPath);

    // 1. Embedded metadata: KPlugin.Id must identify our plugin.
    //    QPluginLoader::metaData() nests the Q_PLUGIN_METADATA file content
    //    under the "MetaData" key.
    const QJsonObject metaData = loader.metaData();
    const QString pluginId = metaData.value(QLatin1String("MetaData"))
                                 .toObject()
                                 .value(QLatin1String("KPlugin"))
                                 .toObject()
                                 .value(QLatin1String("Id"))
                                 .toString();
    if (pluginId != QLatin1String("weatherevents")) {
        std::fprintf(stderr,
                     "PROBE FAILED: KPlugin.Id is '%s', expected 'weatherevents'; metaData=%s\n",
                     qUtf8Printable(pluginId),
                     QJsonDocument(metaData).toJson(QJsonDocument::Compact).constData());
        return 1;
    }

    // 2. KPluginMetaData view of the same file (KCoreAddons-level check).
    const KPluginMetaData pluginMetaData(loader);
    if (!pluginMetaData.isValid()) {
        std::fprintf(stderr, "PROBE FAILED: KPluginMetaData built from the file is invalid\n");
        return 1;
    }
    std::printf("KPluginMetaData: name='%s' version='%s'\n",
                qUtf8Printable(pluginMetaData.name()),
                qUtf8Printable(pluginMetaData.version()));

    // 3. Actual dlopen + plugin bootstrap.
    if (!loader.load()) {
        std::fprintf(stderr,
                     "PROBE FAILED: loader.load() failed: %s\n",
                     qUtf8Printable(loader.errorString()));
        return 1;
    }

    // 4. Interface check.
    auto *plugin = qobject_cast<CalendarEvents::CalendarEventsPlugin *>(loader.instance());
    if (plugin == nullptr) {
        std::fprintf(stderr,
                     "PROBE FAILED: qobject_cast<CalendarEvents::CalendarEventsPlugin*> "
                     "returned nullptr\n");
        return 1;
    }

    // 5. dataReady must be emitted; without a configured location the set is
    //    empty and no fetch is attempted (offline-deterministic).
    int eventCount = -1;
    QObject::connect(plugin,
                     &CalendarEvents::CalendarEventsPlugin::dataReady,
                     [&eventCount](const QMultiHash<QDate, CalendarEvents::EventData> &data) {
                         eventCount = static_cast<int>(data.size());
                     });

    const QDate today = QDate::currentDate();
    plugin->loadEventsForDateRange(today, today);

    QEventLoop loop;
    QTimer::singleShot(2000, &loop, &QEventLoop::quit);
    loop.exec();

    if (eventCount < 0) {
        std::fprintf(stderr, "PROBE FAILED: dataReady was not emitted\n");
        return 1;
    }
    if (eventCount != 0) {
        std::fprintf(stderr,
                     "PROBE FAILED: expected 0 events without a configured location, got %d\n",
                     eventCount);
        return 1;
    }

    std::printf("PROBE OK events=%d\n", eventCount);
    return 0;
}
