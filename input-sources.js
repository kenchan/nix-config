// 入力ソースを macSKK(ASCII モードだけ)に揃える。osascript -l JavaScript で実行する。
// defaults の com.apple.HIToolbox は書いても安定して反映されないので、TIS の API を直接呼ぶ。
// - macSKK 本体と ASCII モードを有効にする(ひらがななどのモードは macSKK の中で切り替えるので有効にしない)
// - 今の入力ソースが macSKK でなければ ASCII モードに切り替える
// 引数: macSKK.app のパス
ObjC.import("Carbon");

const BUNDLE = "net.mtgto.inputmethod.macSKK";
const ENABLE = [BUNDLE, BUNDLE + ".ascii"];
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

  // 入れた直後でまだ macOS に登録されていなければ登録する
  if (!byId[BUNDLE]) {
    $.TISRegisterInputSource($.NSURL.fileURLWithPath(argv[0]));
    byId = sources();
    if (!byId[BUNDLE]) return "警告: macSKK が入力ソースとして見つかりません(" + argv[0] + ")";
    log.push("macSKK を登録しました");
  }

  for (const id of ENABLE) {
    if (!isEnabled(byId[id])) {
      $.TISEnableInputSource(byId[id]);
      log.push(id + " を有効にしました");
    }
  }

  // 有効にしたと返っても実際には有効にならないことがあるので、読み直して確かめる
  byId = sources();
  const failed = ENABLE.filter((id) => !isEnabled(byId[id]));
  if (failed.length) return log.concat("警告: 有効にできませんでした: " + failed.join(", ")).join("\n");

  const current = sourceId(ObjC.castRefToObject($.TISCopyCurrentKeyboardInputSource()));
  if (!current || !current.startsWith(BUNDLE)) {
    $.TISSelectInputSource(byId[SELECT]);
    log.push(current + " から " + SELECT + " に切り替えました");
  }

  return log.join("\n");
}
