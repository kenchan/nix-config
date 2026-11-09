// 入力ソースを macSKK(ASCII とひらがなのモード)に揃える。osascript -l JavaScript で実行する。
// defaults の com.apple.HIToolbox は書いても安定して反映されないので、TIS の API を直接呼ぶ。
// - macSKK 本体と ASCII・ひらがなのモードを有効にする。ひらがなも入力ソースにしておくと、Ctrl+J で
//   入力ソースそのものが切り替わり、Ghostty などのターミナルが IME の処理だと判断できる
//   (ASCII だけだとモードが macSKK の中で変わるだけで、ターミナルが Ctrl+J や l/q も自分で処理してしまう)
// - 今の入力ソースが macSKK でなければ ASCII モードに切り替える
// 引数: macSKK.app のパス
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

  // 有効にしたと返っても実際には有効にならないことがあるので、読み直して確かめる。
  // 入力モードは有効になるまで少しかかるので、何度か待って読み直す
  let failed = [];
  for (let i = 0; i < 10; i++) {
    byId = sources();
    failed = ENABLE.filter((id) => !isEnabled(byId[id]));
    if (!failed.length) break;
    delay(0.3);
  }
  if (failed.length) return log.concat("警告: 有効にできませんでした: " + failed.join(", ")).join("\n");

  const current = sourceId(ObjC.castRefToObject($.TISCopyCurrentKeyboardInputSource()));
  if (!current || !current.startsWith(BUNDLE)) {
    $.TISSelectInputSource(byId[SELECT]);
    log.push(current + " から " + SELECT + " に切り替えました");
  }

  return log.join("\n");
}
