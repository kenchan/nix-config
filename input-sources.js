// Sets the input sources to macSKK (its ASCII and hiragana modes). Run with `osascript -l JavaScript`.
// Writing com.apple.HIToolbox with `defaults` does not apply reliably, so this calls the TIS API directly.
// - Enables macSKK and its ASCII and hiragana modes. With hiragana as an input source too, Ctrl+J changes
//   the input source itself, so terminals such as Ghostty can tell the IME handled the key
//   (with ASCII alone the mode changes only inside macSKK, and the terminal also handles Ctrl+J and l/q).
// - Switches to the ASCII mode unless macSKK is already selected.
// Argument: path to macSKK.app
ObjC.import("Carbon");

const BUNDLE = "net.mtgto.inputmethod.macSKK";
const ENABLE = [BUNDLE, BUNDLE + ".ascii", BUNDLE + ".hiragana"];
const SELECT = BUNDLE + ".ascii";

function prop(source, key) {
  const v = $.TISGetInputSourceProperty(source, key);
  return v ? ObjC.castRefToObject(v) : null;
}

function sourceId(source) {
  const id = prop(source, $.kTISPropertyInputSourceID);
  return id ? id.js : null;
}

function isEnabled(source) {
  const v = prop(source, $.kTISPropertyInputSourceIsEnabled);
  return v ? v.boolValue : false;
}

function sources() {
  const list = ObjC.castRefToObject($.TISCreateInputSourceList($(), true));
  const byId = {};
  for (let i = 0; i < list.count; i++) {
    const s = list.objectAtIndex(i);
    const id = sourceId(s);
    if (id && id.startsWith(BUNDLE)) byId[id] = s;
  }
  return byId;
}

function run(argv) {
  const log = [];
  let byId = sources();

  // Register macSKK if macOS doesn't know it yet, right after installing
  if (!byId[BUNDLE]) {
    $.TISRegisterInputSource($.NSURL.fileURLWithPath(argv[0]));
    byId = sources();
    if (!byId[BUNDLE]) return "warning: macSKK not found as an input source (" + argv[0] + ")";
    log.push("registered macSKK");
  }

  for (const id of ENABLE) {
    if (!isEnabled(byId[id])) {
      $.TISEnableInputSource(byId[id]);
      log.push("enabled " + id);
    }
  }

  // Enabling can report success without taking effect, so read the state back to check.
  // An input mode takes a moment to show as enabled, so retry a few times.
  let failed = [];
  for (let i = 0; i < 10; i++) {
    byId = sources();
    failed = ENABLE.filter((id) => !isEnabled(byId[id]));
    if (!failed.length) break;
    delay(0.3);
  }
  if (failed.length) return log.concat("warning: could not enable " + failed.join(", ")).join("\n");

  const current = sourceId(ObjC.castRefToObject($.TISCopyCurrentKeyboardInputSource()));
  if (!current || !current.startsWith(BUNDLE)) {
    $.TISSelectInputSource(byId[SELECT]);
    log.push("switched from " + current + " to " + SELECT);
  }

  return log.join("\n");
}
