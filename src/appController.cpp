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

// "Remember last used" keys — see the Q_PROPERTY declarations' own comment
// in appController.h for why these have no NOTIFY. lastWordLanguage's own
// key name predates it being shared with manual (non-AI) word entry too.
constexpr auto kLastWordLanguageKey   = "WordSet/lastLanguage";
constexpr auto kAiWordSetWordCountKey = "AiWordSet/wordCount";
constexpr auto kAiRuleSetTopicLanguageKey = "AiRuleSet/topicLanguage";
constexpr auto kAiRuleSetIncludeTheoryKey = "AiRuleSet/includeTheory";
constexpr auto kAiRuleSetGapCountKey      = "AiRuleSet/gapCount";
constexpr auto kAiRuleSetMcCountKey       = "AiRuleSet/mcCount";
constexpr auto kAiRuleSetComboCountKey    = "AiRuleSet/comboCount";
constexpr auto kAiRuleSetDragdropCountKey = "AiRuleSet/dragdropCount";
}

AppController::AppController(QObject *parent) {
    // Rule sets share RecSetManager's folder tree (order/uniqueness) but
    // own their own content vector — wire the two managers together before
    // anything tries to create/move/query a rule set.
    m_recSetManager.setRuleSetManager(&m_ruleSetManager);
    m_ruleSetManager.setRecSetManager(&m_recSetManager);
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

QString AppController::ruleDataFilePath() const {
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/rulesets.json";
}

void AppController::saveData() {
    m_recSetManager.saveAllToJson(dataFilePath());
    m_ruleSetManager.saveAllToJson(ruleDataFilePath());
}

bool AppController::loadData() {
    // Rule sets are a newer, separate file — its absence (e.g. on first
    // run, or an install predating this feature) isn't a load failure the
    // way a missing/corrupt wordsets.json would be.
    m_ruleSetManager.loadFromJson(ruleDataFilePath());
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

int AppController::lastWordLanguage() const {
    return QSettings().value(QLatin1String(kLastWordLanguageKey),
                              static_cast<int>(LanguageHelper::English)).toInt();
}

void AppController::setLastWordLanguage(int languageId) {
    QSettings().setValue(QLatin1String(kLastWordLanguageKey), languageId);
}

int AppController::aiWordSetWordCount() const {
    return QSettings().value(QLatin1String(kAiWordSetWordCountKey), 10).toInt();
}

void AppController::setAiWordSetWordCount(int count) {
    QSettings().setValue(QLatin1String(kAiWordSetWordCountKey), count);
}

int AppController::aiRuleSetTopicLanguage() const {
    return QSettings().value(QLatin1String(kAiRuleSetTopicLanguageKey),
                              static_cast<int>(LanguageHelper::English)).toInt();
}

void AppController::setAiRuleSetTopicLanguage(int languageId) {
    QSettings().setValue(QLatin1String(kAiRuleSetTopicLanguageKey), languageId);
}

bool AppController::aiRuleSetIncludeTheory() const {
    return QSettings().value(QLatin1String(kAiRuleSetIncludeTheoryKey), true).toBool();
}

void AppController::setAiRuleSetIncludeTheory(bool value) {
    QSettings().setValue(QLatin1String(kAiRuleSetIncludeTheoryKey), value);
}

int AppController::aiRuleSetGapCount() const {
    return QSettings().value(QLatin1String(kAiRuleSetGapCountKey), 5).toInt();
}

void AppController::setAiRuleSetGapCount(int count) {
    QSettings().setValue(QLatin1String(kAiRuleSetGapCountKey), count);
}

int AppController::aiRuleSetMcCount() const {
    return QSettings().value(QLatin1String(kAiRuleSetMcCountKey), 5).toInt();
}

void AppController::setAiRuleSetMcCount(int count) {
    QSettings().setValue(QLatin1String(kAiRuleSetMcCountKey), count);
}

int AppController::aiRuleSetComboCount() const {
    return QSettings().value(QLatin1String(kAiRuleSetComboCountKey), 0).toInt();
}

void AppController::setAiRuleSetComboCount(int count) {
    QSettings().setValue(QLatin1String(kAiRuleSetComboCountKey), count);
}

int AppController::aiRuleSetDragdropCount() const {
    return QSettings().value(QLatin1String(kAiRuleSetDragdropCountKey), 0).toInt();
}

void AppController::setAiRuleSetDragdropCount(int count) {
    QSettings().setValue(QLatin1String(kAiRuleSetDragdropCountKey), count);
}
