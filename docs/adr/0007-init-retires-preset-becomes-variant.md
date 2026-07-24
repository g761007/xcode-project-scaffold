# `init` 退役給 `generate`;`--preset` 的四個組合改掛 `--variant`

v0.4 定案 CLI 的兩個入口：互動入口是 `new`，非互動生成入口是 `generate`——讀既有
`scaffold.yml`（`--config`，預設 `./scaffold.yml`），執行前顯示摘要並等待確認，
`--yes` 跳過確認但不跳過驗證、計畫解析與目的地規則。`init` 的兩個職責由它們接手：

    init --config existing.yml   →  generate --config existing.yml
    init MyApp --preset ios-uikit →  new MyApp --variant ios-uikit --yes

`init` 進入棄用期：仍可運作，但每次執行都在 stderr 指向新指令，v0.6 移除。四個平台
組合（`ios-uikit` / `ios-swiftui` / `macos-swiftui` / `macos-appkit`）從 `--preset`
改掛 `--variant`，程式碼中的型別同步改名 `Variant`（`Preset` 留過渡別名）；在 `new`
上輸入 `--preset` 得到 "did you mean --variant?" 的明確錯誤。**preset 一詞保留給
v0.7 的專案規模語意**（minimal / standard / production，§17.2）。

本決策**部分推翻 ADR-0005**：該 ADR 以 `init` 作為非互動契約的守門人，並把非 TTY
下的 `new` 使用者導向 `init --config/--preset`；守門人現在是 `generate`，錯誤訊息
也改為指向 `generate --config` 與 `new --variant --yes`。ADR-0005 的核心結論——
互動與非互動分成兩個指令、prompt 不內嵌相容性規則——不變。

## 為什麼

**`init` 的動詞說錯了它做的事。** 在 `git init`、`npm init` 的慣例裡，init 意味
「就地初始化目前目錄」；xscaffold 的 `init` 卻是「在別處生成一個新專案」。`generate`
說的就是它做的事，而它與 `new` 的分工可以用一句話講完：一個消費既有設定，一個創作
新設定——沒有語意翻轉。

**`--preset` 佔著一個即將改義的詞。** v0.7 的 preset 指專案規模與預設功能。若四個
平台組合繼續佔用這個詞，回歸時同一個 flag 有兩段互相矛盾的歷史，文件與錯誤訊息都得
解釋兩遍。platform × interface 的組合在 CONTEXT.md 裡本來就叫 Variant——flag 跟著
詞彙走，而不是詞彙遷就 flag。

**現在轉，只付一次成本。** 工具尚未對外推廣（§25），今天改契約影響的是少數早期
使用者與我們自己的腳本；等推廣後再改，同樣的翻轉要付長棄用期、遷移指南與兩套並存
文件的代價。因此 v0.4 一次完成：`generate` 上線、`init` 棄用、preset→variant 轉移。
`init` 仍保留兩個小版本的警告期，因為刪一個入口的成本（改一行腳本）與留一個警告的
成本不對稱——警告近乎免費。

**確認畫面是 `generate` 的新增能力，不適合補在 `init` 上。** 非互動生成執行前顯示
摘要並等待確認（無終端且無 `--yes` 時以 exit 2 拒絕而非卡住），讓人類誤操作的保護
與 CI/AI Agent 的路徑（`--yes --output json`）並存。把這層補在 `init` 上等於改變
既有腳本的行為；新指令從第一天就帶著它。

## 代價

過渡期指令從五個變六個（`init` 與 `generate` 並存至 v0.6），help 與文件要同時認得
兩個入口。既有 `init` 腳本必須在兩個小版本內遷移；警告印在 stderr、不污染
`--output json` 的 stdout，但對 log 嚴格的 pipeline 仍是可見的雜訊。

`Preset` 型別以 `typealias Preset = Variant` 過渡，v0.6 隨 `init` 一併移除；在那
之前同一型別有兩個名字，靠別名旁的註解說明為何。`new` 上的 `--preset` 是隱藏
option，定義出來只為了報 "did you mean --variant?"——這是刻意保留的表面積，等
v0.7 preset 以規模語意回歸時由新的實作取代。
