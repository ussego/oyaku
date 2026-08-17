import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import QtQuick.Controls as QQC

// Oyaku translation panel. Loaded internally by BarWidget.qml; not a standalone panel plugin.
Panel {
  id: root
  moduleName: "ussego.oyaku"
  ipcTarget: "ussego.oyaku"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: root.barForeground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var defaultTargets: ["en", "es", "ja"]

  readonly property var languageOptions: [
    { value: "af", label: "Afrikaans" },
    { value: "sq", label: "Albanian" },
    { value: "am", label: "Amharic" },
    { value: "ar", label: "Arabic" },
    { value: "hy", label: "Armenian" },
    { value: "az", label: "Azerbaijani" },
    { value: "eu", label: "Basque" },
    { value: "bn", label: "Bengali" },
    { value: "bs", label: "Bosnian" },
    { value: "bg", label: "Bulgarian" },
    { value: "ca", label: "Catalan" },
    { value: "zh", label: "Chinese" },
    { value: "zh-TW", label: "Chinese (Traditional)" },
    { value: "hr", label: "Croatian" },
    { value: "cs", label: "Czech" },
    { value: "da", label: "Danish" },
    { value: "nl", label: "Dutch" },
    { value: "en", label: "English" },
    { value: "et", label: "Estonian" },
    { value: "fi", label: "Finnish" },
    { value: "fr", label: "French" },
    { value: "gl", label: "Galician" },
    { value: "ka", label: "Georgian" },
    { value: "de", label: "German" },
    { value: "el", label: "Greek" },
    { value: "gu", label: "Gujarati" },
    { value: "ht", label: "Haitian Creole" },
    { value: "ha", label: "Hausa" },
    { value: "he", label: "Hebrew" },
    { value: "hi", label: "Hindi" },
    { value: "hu", label: "Hungarian" },
    { value: "is", label: "Icelandic" },
    { value: "id", label: "Indonesian" },
    { value: "ga", label: "Irish" },
    { value: "it", label: "Italian" },
    { value: "ja", label: "Japanese" },
    { value: "kn", label: "Kannada" },
    { value: "ko", label: "Korean" },
    { value: "lv", label: "Latvian" },
    { value: "lt", label: "Lithuanian" },
    { value: "mk", label: "Macedonian" },
    { value: "ms", label: "Malay" },
    { value: "ml", label: "Malayalam" },
    { value: "mt", label: "Maltese" },
    { value: "mi", label: "Maori" },
    { value: "mr", label: "Marathi" },
    { value: "mn", label: "Mongolian" },
    { value: "ne", label: "Nepali" },
    { value: "no", label: "Norwegian" },
    { value: "fa", label: "Persian" },
    { value: "pl", label: "Polish" },
    { value: "pt", label: "Portuguese" },
    { value: "pa", label: "Punjabi" },
    { value: "ro", label: "Romanian" },
    { value: "ru", label: "Russian" },
    { value: "sr", label: "Serbian" },
    { value: "sk", label: "Slovak" },
    { value: "sl", label: "Slovenian" },
    { value: "so", label: "Somali" },
    { value: "es", label: "Spanish" },
    { value: "sw", label: "Swahili" },
    { value: "sv", label: "Swedish" },
    { value: "tl", label: "Tagalog" },
    { value: "ta", label: "Tamil" },
    { value: "te", label: "Telugu" },
    { value: "th", label: "Thai" },
    { value: "tr", label: "Turkish" },
    { value: "uk", label: "Ukrainian" },
    { value: "ur", label: "Urdu" },
    { value: "vi", label: "Vietnamese" },
    { value: "cy", label: "Welsh" },
    { value: "yi", label: "Yiddish" },
    { value: "zu", label: "Zulu" }
  ]
  readonly property var sourceOptions: [{ value: "auto", label: "Auto-detect" }].concat(root.languageOptions)

  // Session input state.
  property string sourceText: "auto"
  property string targetText: setting("target", defaultTargets[0])
  property string inputText: ""
  property string resultText: ""

  // Used by clipboard-paste IPC commands to trigger translation after pasting.
  property bool _translateAfterPaste: false

  // User-configurable quick-target buttons; falls back to the default list.
  property var quickTargets: setting("targets", root.defaultTargets)

  // Tracks the target language before the most recent target change,
  // so a source/target collision can fall back to the previous target.
  property string _previousTarget: ""

  function open() {
    root.controller.show()
    Qt.callLater(function() { if (inputArea) inputArea.forceActiveFocus() })
  }

  function close() { root.controller.hide() }

  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    for (var k in values) entry[k] = values[k]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setTarget(code) {
    var c = String(code || "").trim().toLowerCase()
    if (c === "" || c === root.targetText) return
    root._previousTarget = root.targetText
    root.targetText = c
    persistSettings({ target: c })
  }

  function addQuickTarget(code) {
    var c = String(code || "").trim().toLowerCase()
    if (c === "") return
    if (root.quickTargets.indexOf(c) >= 0) {
      root.setTarget(c)
      return
    }
    if (root.quickTargets.length >= 4) return
    var list = root.quickTargets.slice()
    list.push(c)
    root.quickTargets = list
    root.persistSettings({ targets: list })
    root.setTarget(c)
  }

  function removeQuickTarget(code) {
    var c = String(code || "").trim().toLowerCase()
    var list = []
    for (var i = 0; i < root.quickTargets.length; i++)
      if (root.quickTargets[i] !== c) list.push(root.quickTargets[i])
    if (list.length === 0) list = root.defaultTargets.slice()
    root.quickTargets = list
    root.persistSettings({ targets: list })
  }

  function doTranslate() {
    service.translate(root.sourceText, root.targetText, root.inputText)
  }

  function doSwap() {
    var s = String(root.sourceText).trim().toLowerCase()
    if (s === "" || s === "auto") return
    var t = root.targetText
    root.sourceText = t
    root.setTarget(s)
  }

  function doCopy() {
    var text = root.resultText
    if (!text) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
  }

  function pasteFromClipboard(andTranslate) {
    if (clipboardProc.running) return
    root._translateAfterPaste = andTranslate === true
    clipboardProc.running = true
  }

  onSourceTextChanged: { if (sourceDropdown) sourceDropdown.value = root.sourceText }
  onTargetTextChanged: { if (targetDropdown) targetDropdown.value = root.targetText }

  onOpenedChanged: {
    if (root.opened) {
      root.resultText = ""
      service.checkAvailability()
      Qt.callLater(function() { if (inputArea) inputArea.forceActiveFocus() })
    }
  }

  Component.onCompleted: {
    service.checkAvailability()
    if (sourceDropdown) sourceDropdown.value = root.sourceText
    if (targetDropdown) targetDropdown.value = root.targetText
  }

  TranslateService {
    id: service
    onResultChanged: { root.resultText = service.result }
    onErrorChanged: {}
  }

  Process {
    id: clipboardProc
    command: ["wl-paste", "--no-newline"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = String(this.text || "").trim()
        if (inputArea) {
          inputArea.text = text
          inputArea.forceActiveFocus()
        }
        if (root._translateAfterPaste && text !== "" && service.transAvailable)
          root.doTranslate()
        root._translateAfterPaste = false
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }

    function paste() {
      root.open()
      root.pasteFromClipboard(false)
    }

    function translate() {
      root.open()
      root.pasteFromClipboard(true)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: sourceDropdown.popupOpen || targetDropdown.popupOpen || addTargetPopup.opened || inputArea.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onReturnRequested: root.doTranslate()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Text {
          width: parent.width
          text: "OYAKU"
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
        }

        // Source language row.
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "FROM"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          SearchableDropdown {
            id: sourceDropdown
            width: parent.width - x - swapButton.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            showLabel: false
            triggerLabel: "Source..."
            placeholderText: "Search language..."
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            options: root.sourceOptions
            onChanged: function(v) {
              // If the new source collides with the current target, move the target
              // to the previous target (defaulting to English) instead of the source.
              if (v === root.targetText) {
                var fallback = root._previousTarget || "en"
                root.setTarget(fallback)
              }
              root.sourceText = v
            }
          }

          PanelActionButton {
            id: swapButton
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰯍"
            tooltipText: "Swap source and target"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            enabled: root.sourceText !== "" && root.sourceText !== "auto" && service.transAvailable
            onClicked: root.doSwap()
          }
        }

        // Target language row: quick picks + a free-text field.
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "TO"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Row {
            id: quickTargets
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Repeater {
              model: root.quickTargets

              Button {
                id: quickBtn
                required property var modelData
                text: String(modelData).toUpperCase()
                selected: root.targetText === String(modelData).toLowerCase()
                bordered: true
                fontSize: Style.font.bodySmall
                foreground: root.contentForeground
                enabled: service.transAvailable
                onClicked: root.setTarget(modelData)

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.RightButton
                  onClicked: root.removeQuickTarget(quickBtn.modelData)
                }
              }
            }

            PanelActionButton {
              id: addTargetButton
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰐕"
              tooltipText: root.quickTargets.length >= 4 ? "Maximum 4 quick targets" : "Add quick target"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              enabled: root.quickTargets.length < 4
              onClicked: addTargetPopup.open()
            }

            QQC.Popup {
              id: addTargetPopup
              width: Style.space(220)
              height: Style.space(160)
              modal: false
              focus: true
              closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutsideParent

              background: BorderSurface {
                color: Color.popups.background
                borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
                radius: Style.cornerRadius
              }

              SearchableDropdown {
                id: addDropdown
                anchors.fill: parent
                anchors.margins: Style.space(8)
                showLabel: false
                triggerLabel: "Add language..."
                placeholderText: "Search language..."
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                options: root.languageOptions
                onChanged: function(v) {
                  root.addQuickTarget(v)
                  addTargetPopup.close()
                }
              }
            }
          }

          SearchableDropdown {
            id: targetDropdown
            width: Math.max(Style.space(50), parent.width - x - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            showLabel: false
            triggerLabel: "Language..."
            placeholderText: "Search language..."
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            options: root.languageOptions
            onChanged: function(v) {
              // If the new target collides with the current source, swap the source
              // to the previous target to keep the pair meaningful.
              if (v === root.sourceText) root.sourceText = root.targetText
              root.setTarget(v)
            }
          }
        }

        // Multi-line source text with vertical scrolling for long input.
        QQC.ScrollView {
          id: inputScroll
          width: parent.width
          height: Style.space(96)
          clip: true
          QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
          QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded

          background: BorderSurface {
            color: Style.controlFill(inputArea.activeFocus, false, root.contentForeground, Color.accent)
            borderSpec: Border.controlSpec(inputArea.activeFocus ? "focus" : "normal", root.contentForeground, Color.accent)
            radius: Style.cornerRadius
          }

          QQC.TextArea {
            id: inputArea
            width: inputScroll.availableWidth
            height: Math.max(implicitHeight, inputScroll.availableHeight)
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            placeholderText: "Enter text to translate…"
            placeholderTextColor: Qt.darker(root.contentForeground, 1.6)
            selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
            selectedTextColor: root.contentForeground
            wrapMode: QQC.TextArea.Wrap
            activeFocusOnTab: false
            text: ""
            background: null
            onTextChanged: root.inputText = text

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }
              if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.switchPanel((event.modifiers & Qt.ShiftModifier) || event.key === Qt.Key_Backtab ? -1 : 1)
                event.accepted = true
                return
              }
              if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                root.doTranslate()
                event.accepted = true
              }
            }
          }
        }

        Button {
          width: parent.width
          iconText: "󰊿"
          text: "Translate"
          bordered: true
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          enabled: service.transAvailable && !service.loading && root.inputText !== ""
          onClicked: root.doTranslate()
        }

        // Status / loading / error message.
        Text {
          width: parent.width
          visible: service.checking || service.loading || service.error !== ""
          text: service.checking
            ? "Checking for translate-shell…"
            : (service.loading ? "Translating…" : service.error)
          color: service.error ? Color.urgent : Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        // Result area with one-click copy.
        Item {
          width: parent.width
          height: resultColumn.height
          visible: root.resultText !== "" && !service.loading

          Column {
            id: resultColumn
            width: parent.width
            spacing: Style.space(6)

            Row {
              spacing: Style.space(8)

              Text {
                text: "RESULT"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              PanelActionButton {
                iconText: "󰆏"
                tooltipText: "Copy translation"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.doCopy()
              }
            }

            BorderSurface {
              width: parent.width
              height: resultEdit.height + Style.space(12)
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
              borderSpec: Border.none()
              radius: Style.cornerRadius

              TextEdit {
                id: resultEdit
                anchors.verticalCenter: parent.verticalCenter
                x: Style.space(8)
                width: parent.width - Style.space(16)
                text: root.resultText
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                wrapMode: TextEdit.WordWrap
                readOnly: true
                selectByMouse: true
                selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
                selectedTextColor: root.contentForeground
              }
            }
          }
        }
      }
    }
  }
}
