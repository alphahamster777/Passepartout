#pragma once

#include <QList>
#include <QString>
#include <QObject>
#include <QDir>
#include <QStandardPaths>
#include <QtQml/qqml.h>

#include "baseTestController.h"
#include "recSetManager.h"
#include "ruleSetManager.h"

class QQmlEngine;
class QJSEngine;

class AppController: public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(RecSetManager* recSetManager READ recSetManager CONSTANT)
    Q_PROPERTY(RuleSetManager* ruleSetManager READ ruleSetManager CONSTANT)
    Q_PROPERTY(QList<QString> recSetNameList READ getRecSetNameList NOTIFY recSetNameListChanged)
    // BaseTestController::SpellingStrictness value (Strict/Normal/Lenient),
    // persisted via QSettings so it's remembered across sessions. Read
    // directly from the same QSettings key by checkTypedAnswer() itself —
    // this property exists so QML has something to bind the picker to.
    Q_PROPERTY(int spellingStrictness READ spellingStrictness WRITE setSpellingStrictness NOTIFY spellingStrictnessChanged)
    // LanguageHelper::Language the UI is displayed in. Persisted once the
    // user picks one in Settings; before that, interfaceLanguage() itself
    // resolves a system-locale guess on every read rather than persisting
    // one, so it keeps tracking the device's language until the user
    // actually makes a choice of their own.
    Q_PROPERTY(int interfaceLanguage READ interfaceLanguage WRITE setInterfaceLanguage NOTIFY interfaceLanguageChanged)
    // The hint/meaning language a brand-new word set's first card starts
    // with. Follows interfaceLanguage until the user explicitly sets a hint
    // language while creating a new set (see CreatingRecSet.qml), at which
    // point that choice sticks (persisted separately) regardless of any
    // later interface-language change.
    Q_PROPERTY(int defaultMeaningLanguage READ defaultMeaningLanguage WRITE setDefaultMeaningLanguage NOTIFY defaultMeaningLanguageChanged)

    // Remembers CreatingRecSet.qml's last-used word language across
    // sessions — shared by both its AI generator dialog and a brand-new
    // set's first (or next, after "+ Add word") manually-typed word, since
    // both are "what language are these words in" for the same set. No
    // "follows interfaceLanguage" behavior the way defaultMeaningLanguage
    // (used for the hint language default, below and in the AI dialog
    // alike) has — it's a plain remembered value, defaulting to English on
    // a clean launch. No NOTIFY here or on aiWordSetWordCount — each is
    // only ever read once, at its control's own creation, and written back
    // when that control changes; nothing else needs to react live to them.
    Q_PROPERTY(int lastWordLanguage READ lastWordLanguage WRITE setLastWordLanguage)
    Q_PROPERTY(int aiWordSetWordCount READ aiWordSetWordCount WRITE setAiWordSetWordCount)

    // Same idea, for the AI Rule Set Generator (CreatingRuleSet.qml). Its
    // Explanation Language already reuses defaultMeaningLanguage above (same
    // "hint/meaning language" concept); Topic Language gets its own plain
    // remembered value here, same shape as lastWordLanguage.
    Q_PROPERTY(int aiRuleSetTopicLanguage READ aiRuleSetTopicLanguage WRITE setAiRuleSetTopicLanguage)
    Q_PROPERTY(bool aiRuleSetIncludeTheory READ aiRuleSetIncludeTheory WRITE setAiRuleSetIncludeTheory)
    Q_PROPERTY(int aiRuleSetGapCount READ aiRuleSetGapCount WRITE setAiRuleSetGapCount)
    Q_PROPERTY(int aiRuleSetMcCount READ aiRuleSetMcCount WRITE setAiRuleSetMcCount)
    Q_PROPERTY(int aiRuleSetComboCount READ aiRuleSetComboCount WRITE setAiRuleSetComboCount)
    Q_PROPERTY(int aiRuleSetDragdropCount READ aiRuleSetDragdropCount WRITE setAiRuleSetDragdropCount)

public:
    // No default argument, deliberately: Qt's QML_SINGLETON registration
    // checks std::is_default_constructible<T> BEFORE it looks for a custom
    // create() factory, and unconditionally wins if that's true — so a
    // default-constructible AppController would make Qt silently construct
    // it via `new AppController()` instead of calling create() below,
    // leaving m_engine permanently unset.
    explicit AppController(QObject* parent);

    Q_INVOKABLE RecSetManager* recSetManager() {
        return &m_recSetManager;
    }

    Q_INVOKABLE RuleSetManager* ruleSetManager() {
        return &m_ruleSetManager;
    }

    QList<QString> getRecSetNameList() const;

    Q_INVOKABLE void saveData();
    Q_INVOKABLE bool loadData();

    int spellingStrictness() const;
    void setSpellingStrictness(int value);

    int interfaceLanguage() const;
    void setInterfaceLanguage(int languageId);

    int defaultMeaningLanguage() const;
    void setDefaultMeaningLanguage(int languageId);

    int lastWordLanguage() const;
    void setLastWordLanguage(int languageId);
    int aiWordSetWordCount() const;
    void setAiWordSetWordCount(int count);

    int aiRuleSetTopicLanguage() const;
    void setAiRuleSetTopicLanguage(int languageId);
    bool aiRuleSetIncludeTheory() const;
    void setAiRuleSetIncludeTheory(bool value);
    int aiRuleSetGapCount() const;
    void setAiRuleSetGapCount(int count);
    int aiRuleSetMcCount() const;
    void setAiRuleSetMcCount(int count);
    int aiRuleSetComboCount() const;
    void setAiRuleSetComboCount(int count);
    int aiRuleSetDragdropCount() const;
    void setAiRuleSetDragdropCount(int count);

    // Reads the persisted interface-language choice, falling back to the
    // system locale's closest match (without persisting that guess) when
    // the user hasn't picked one yet. Shared with main.cpp, which needs to
    // install the right QTranslator before any QML — and so before this
    // singleton even exists — has loaded.
    static int resolveInterfaceLanguage();

    // (Re)installs a process-lifetime QTranslator for languageId, replacing
    // whatever it currently holds. No-op beyond uninstalling for English,
    // since that's the qsTr() source language and needs no .qm. Also used
    // directly by main.cpp for the same reason as resolveInterfaceLanguage().
    static void applyInterfaceLanguage(int languageId);

    // Qt's QML_SINGLETON machinery calls this only because AppController is
    // no longer default-constructible (see the constructor above) — it must
    // be named exactly "create" and return the concrete type, per
    // QQmlPrivate::HasSingletonFactory's detection in qqmlprivate.h.
    static AppController* create(QQmlEngine* engine, QJSEngine*) {
        auto* controller = new AppController(nullptr);
        controller->m_engine = engine;
        return controller;
    }

signals:
    void recSetNameListChanged();
    void spellingStrictnessChanged();
    void interfaceLanguageChanged();
    void defaultMeaningLanguageChanged();

private:
    RecSetManager m_recSetManager;
    RuleSetManager m_ruleSetManager;
    QQmlEngine* m_engine = nullptr;
    QString dataFilePath() const;
    QString ruleDataFilePath() const;
};
