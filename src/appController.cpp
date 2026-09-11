#include "appController.h"
#include "languageHelper.h"

#include <QSettings>
#include <QTranslator>
#include <QLocale>
#include <QCoreApplication>
#include <QQmlEngine>

namespace {
constexpr auto kInterfaceLanguageKey = "interfaceLanguage";
// Presence (not just value) of this key is what distinguishes "user has
// deliberately picked a hint language for a new set" from "still following
// interfaceLanguage" — see defaultMeaningLanguage()/setDefaultMeaningLanguage().
constexpr auto kMeaningLanguageOverrideKey = "meaningLanguageOverride";
}

AppController::AppController(QObject *parent) {
    loadData();
}

QList<QString> AppController::getRecSetNameList() const {
    QList<QString> ret;
    for (auto& recSet : m_recSetManager.getAllRecSets()) {
        ret.append(recSet.getSetName());
    }
    return ret;
}

QString AppController::dataFilePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/wordsets.json";
}

void AppController::saveData() {
    m_recSetManager.saveAllToJson(dataFilePath());
}

bool AppController::loadData() {
    return m_recSetManager.loadFromJson(dataFilePath());
}

int AppController::spellingStrictness() const {
    return QSettings().value(QLatin1String(BaseTestController::kStrictnessSettingsKey),
                              BaseTestController::Normal).toInt();
}

void AppController::setSpellingStrictness(int value) {
    if (value == spellingStrictness())
        return;
    QSettings().setValue(QLatin1String(BaseTestController::kStrictnessSettingsKey), value);
    emit spellingStrictnessChanged();
}

int AppController::resolveInterfaceLanguage() {
    const QVariant stored = QSettings().value(QLatin1String(kInterfaceLanguageKey));
    if (stored.isValid())
        return stored.toInt();
    return static_cast<int>(LanguageHelper::fromLocale(QLocale::system()));
}

void AppController::applyInterfaceLanguage(int languageId) {
    // Function-local static: lives for the process's whole lifetime once
    // first installed, same as QCoreApplication itself needs it to — a
    // QTranslator must stay alive for as long as it's installed. Shared
    // between main.cpp's initial (pre-QML) install and this class's later
    // runtime language switches so there's only ever one installed at a
    // time, never a stale one left behind by whichever path ran first.
    static QTranslator translator;
    qApp->removeTranslator(&translator);
    const auto lang = static_cast<LanguageHelper::Language>(languageId);
    if (lang == LanguageHelper::English || lang == LanguageHelper::NotSelected)
        return;
    const QString code = LanguageHelper::localeCode(lang);
    if (translator.load(QStringLiteral(":/i18n/app_%1.qm").arg(code)))
        qApp->installTranslator(&translator);
}

int AppController::interfaceLanguage() const {
    return resolveInterfaceLanguage();
}

void AppController::setInterfaceLanguage(int languageId) {
    if (languageId == interfaceLanguage())
        return;
    // Only re-notify defaultMeaningLanguage if it's currently following
    // interfaceLanguage (i.e. no explicit override stored yet) — an
    // already-overridden meaning language must not drift when the user
    // later changes the interface language for unrelated reasons.
    const bool meaningFollowsInterface =
        !QSettings().contains(QLatin1String(kMeaningLanguageOverrideKey));
    QSettings().setValue(QLatin1String(kInterfaceLanguageKey), languageId);
    applyInterfaceLanguage(languageId);
    if (m_engine)
        m_engine->retranslate();
    emit interfaceLanguageChanged();
    if (meaningFollowsInterface)
        emit defaultMeaningLanguageChanged();
}

int AppController::defaultMeaningLanguage() const {
    const QVariant override = QSettings().value(QLatin1String(kMeaningLanguageOverrideKey));
    return override.isValid() ? override.toInt() : interfaceLanguage();
}

void AppController::setDefaultMeaningLanguage(int languageId) {
    if (languageId == defaultMeaningLanguage())
        return;
    QSettings().setValue(QLatin1String(kMeaningLanguageOverrideKey), languageId);
    emit defaultMeaningLanguageChanged();
}
