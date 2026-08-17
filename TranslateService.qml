import QtQuick
import Quickshell
import Quickshell.Io

// Spawns translate-shell (`trans`) and surfaces the result.
// Keeps process handling out of the UI files.
Item {
  id: root

  // True once `trans` was found on PATH. Detection runs lazily on first use.
  property bool transAvailable: false
  property bool checking: false
  property bool loading: false
  property string result: ""
  property string error: ""
  property string transPath: ""

  property string _stderr: ""
  property var _pending: null
  property bool _aborting: false

  signal availabilityChecked()

  function checkAvailability() {
    if (transAvailable || checking || checkProc.running) return
    checking = true
    checkProc.running = true
  }

  function translate(source, target, text) {
    if (checking) {
      _pending = { source: source, target: target, text: text }
      return
    }

    if (!transAvailable) {
      error = "translate-shell not found — install it with `sudo pacman -S translate-shell`"
      return
    }

    if (transProc.running || _aborting) {
      _pending = { source: source, target: target, text: text }
      _aborting = true
      transProc.running = false
      return
    }

    startTranslate(source, target, text)
  }

  function startTranslate(source, target, text) {
    var s = String(source || "").trim().toLowerCase()
    var t = String(target || "").trim().toLowerCase()
    var txt = String(text || "").trim()

    if (t === "") {
      error = "Select a target language"
      return
    }
    if (txt === "") {
      error = "Enter text to translate"
      return
    }

    var pair = (s === "" || s === "auto") ? ":" + t : s + ":" + t

    result = ""
    error = ""
    _stderr = ""
    loading = true

    // Use the detected path if `trans` isn't on the shell's inherited PATH.
    var bin = root.transPath !== "" ? root.transPath : "trans"
    transProc.command = [bin, "-b", "-no-ansi", pair, txt]
    transProc.running = true
    timeoutTimer.restart()
  }

  Process {
    id: checkProc
    // Look in PATH, then a few common install locations (e.g. pip's --user bin dir).
    command: ["sh", "-c", 'cmd=$(command -v trans 2>/dev/null); [ -z "$cmd" ] && [ -x ~/.local/bin/trans ] && cmd=~/.local/bin/trans; [ -z "$cmd" ] && [ -x /usr/local/bin/trans ] && cmd=/usr/local/bin/trans; [ -z "$cmd" ] && [ -x /usr/bin/trans ] && cmd=/usr/bin/trans; printf "%s\\n" "$cmd"']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var path = String(text || "").trim()
        root.transAvailable = path !== ""
        root.transPath = path
        root.checking = false
        root.error = ""
        if (root._pending) {
          var p = root._pending
          root._pending = null
          root.translate(p.source, p.target, p.text)
        }
        root.availabilityChecked()
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.transAvailable = false
        root.transPath = ""
        root.checking = false
        if (root._pending) {
          root._pending = null
          root.error = "translate-shell not found — install it with `sudo pacman -S translate-shell`"
        }
        root.availabilityChecked()
      }
    }
  }

  Process {
    id: transProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!root.loading) return
        root.result = String(text || "").trim()
        if (root.result !== "") {
          root.error = ""
          root.loading = false
          root.timeoutTimer.stop()
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root._stderr = String(text || "").trim()
      }
    }
    onExited: function(exitCode) {
      root.timeoutTimer.stop()

      if (root._aborting) {
        root._aborting = false
        if (root._pending) {
          var p = root._pending
          root._pending = null
          root.startTranslate(p.source, p.target, p.text)
        }
        return
      }

      if (!root.loading) return
      root.loading = false

      if (exitCode !== 0 || root.result === "") {
        root.error = root._stderr || "Translation failed"
      }
    }
  }

  Timer {
    id: timeoutTimer
    interval: 30000
    onTriggered: {
      if (transProc.running) {
        root._aborting = true
        transProc.running = false
      }
      if (root.loading) {
        root.loading = false
        if (root.result !== "") {
          root.error = ""
        } else {
          root.error = "Translation timed out"
        }
      }
    }
  }
}
