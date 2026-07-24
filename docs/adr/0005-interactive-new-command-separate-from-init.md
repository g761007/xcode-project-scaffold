# 互動式建立獨立成 `new` 指令，`init` 維持非互動

v0.2 的互動式建立以新指令 `xscaffold new` 提供，而不是在 `init` 上加 `--interactive` 旗標、也不讓裸 `init` 在 TTY 下自動進互動。`init` 的契約**完全不變**：非互動、可腳本化、必須給 `--config` 或 `--preset`。`new` 互動收集一組精選欄位 → 填出 `PartialProjectConfiguration` → 交給既有的 `validate` → `plan` → 確認 → 走同一條 `init` pipeline 生成。

## 為什麼

`init` 以「機器可讀、可腳本化、禁止互動」為契約核心（§11.3）。把 TTY 互動塞進 `init`，就在這條路徑上多一個依賴 TTY 的分支：管線化情境下若忘了給設定來源，行程可能卡住等 stdin，而這正是腳本最難察覺的失敗。裸 `init` 在 TTY 自動進互動有同樣的隱性問題。

`new` 是不同的動詞——它「創作一份設定並生成」，`init` 只「消費一份既有設定」。分成兩個指令，讓 `init` 的不變式（禁止互動）字面上成立，而不是靠執行期偵測維持。這也與 §16.2 的 Skill 流程同構（理解需求 → `scaffold.yml` → `validate` → `plan` → `init`），只是把 AI 驅動換成人類驅動。

prompt **不內嵌任何相容性規則**（§15）：`new` 照問，把 `validate` 當唯一守門；驗證不過就依 `ValidationIssue.path` 重問對應的那一題、迴圈到通過。相容性邏輯因此仍只有一處，不會在 prompt 與 validation 之間分裂成兩份會漂移的真實。

## 代價

指令從四個變五個，CLI 表面積增加，`doctor` 與文件都要認得多一個入口。

互動帶回 `130`（User cancelled）與 `--yes`（§11.2 早已預告兩者隨互動一起回來）。`new` 必須守住 TTY 與 `--output json` 的邊界：非 TTY 或指定 `--output json` 時以 exit 2 明確報錯，並把使用者導向 `init --config/--preset`。

`new` 依 `issue.path` 對回 prompt 題目需要一層 UX 路由（path → question）。這層路由不是相容性規則，只是把 `validate` 的判決轉譯成「重問哪一題」；對不到任何被問過的題目時（錯誤出在預設欄位），退回顯示 `ValidationIssue` 並中止。
