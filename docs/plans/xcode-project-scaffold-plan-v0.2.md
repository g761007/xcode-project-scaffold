# xcode-project-scaffold v0.2 開發計劃

> 目標讀者：專案擁有者、Code Agent
> Repository：`xcode-project-scaffold`（public）
> CLI：`xscaffold`
> 核心契約：`scaffold.yml`
> 前一版：`v0.1.0`（見 `xcode-project-scaffold-plan.md`）

本版承接 v0.1（四個指令、兩個 iOS variant 已交付）。v0.2 只收兩條主軸——**Architecture overlay 升級（MVVM / MVVM-C）**與**互動式 `new` 指令**——macOS 順延到 v0.3 之後。

用語以 `CONTEXT.md` 為準。範圍以外的邊界一律沿用 v0.1 計劃與 `docs/adr/`。

---

## 1. 定位

定位不變：**只做 init，不管理既有專案**（[ADR-0001](../adr/0001-scaffold-yml-as-birth-certificate.md)）。v0.2 不觸碰這條邊界，只在既有邊界內深化兩件事：

- 讓 `architecture.pattern` 從「只有 minimal 有實體、其餘回報不支援」變成 **MVVM / MVVM-C 真的生得出可運作的專案**。
- 為不想手寫 `scaffold.yml` 的人補上一條**人類 on-ramp**（`new`），與既有的 AI on-ramp（Skill）並列，而 `init` 維持純機器路徑。

---

## 2. v0.2 支援範圍

| 維度 | v0.1 | **v0.2 新增** | 之後 |
|---|---|---|---|
| Platform | iOS | — | macOS（v0.3） |
| Interface | UIKit、SwiftUI | — | AppKit |
| Architecture | Minimal | **MVVM、MVVM-C** | Clean |
| MVVM 適用 | — | **UIKit + SwiftUI** | — |
| MVVM-C 適用 | — | **UIKit only** | SwiftUI router（未定） |
| 範例程式碼 | 無（overlay 只產文件） | **可選的具體範例（取代主畫面）** | — |
| 建立方式 | `init`（宣告式／preset）、Skill | **`new`（互動式）** | — |

**macOS 不在 v0.2。** v0.1 已用 UIKit + SwiftUI 逼出 *interface* 軸的共用邊界；*platform* 軸（目前只有 iOS）留待 v0.3，避免同版塞入兩個高度獨立的大方向。

---

## 3. Architecture overlay 升級

裁決記於 [ADR-0004](../adr/0004-architecture-overlay-generates-a-concrete-example.md)。

### 3.1 overlay 形態

v0.1 的 overlay 只在生成專案的 README 寫一段架構散文（§7.4）。v0.2 升級成**生成一個實際串起來的具體範例**：

- **單一 app target，不變換 XcodeGen spec、不新增 target。** §15 那個「overlay 要不要升級成 spec 變換器」的分叉，這輪判定為不需要——那是 Clean／模組化才有的需求。
- **不生抽象基底層**（`ViewModelProtocol`、`BaseView` 之類）。那是最典型的 scaffold 垃圾。
- 範例**取代 App 主畫面**，不另加平行模組——範例就是 App 真正的起始畫面，沒有「刪掉範例」的雜務。

### 3.2 pattern × interface 相容矩陣

| | UIKit | SwiftUI |
|---|---|---|
| `minimal` | ✅ v0.1 | ✅ v0.1 |
| `mvvm` | ✅ | ✅ |
| `mvvm-c` | ✅ | ❌ `XS0xxx`（這版還沒支援） |

`mvvm-c × swiftui` 回報**能力邊界**而非永遠不合法：coordinator 的存在理由是解 UIKit 命令式導航（`pushViewController`）與 view controller 的耦合，SwiftUI 的 `NavigationStack(path:)` 本來就把導航狀態宣告式外部化，硬套是 router 而非 coordinator。留 `XS0xxx` 的門給日後真正的 SwiftUI router 版。

### 3.3 `architecture.includeExample`

`scaffold.yml` 新增欄位，控制是否生成範例程式碼：

```yaml
architecture:
  pattern: mvvm          # minimal | mvvm | mvvm-c
  includeExample: true   # 預設 true；只在 pattern ∈ {mvvm, mvvm-c} 有意義
```

- **`true`** → 取代 App 主畫面：
  - `mvvm` → 主畫面拆成 View + 具體 ViewModel（ViewModel 驅動一點狀態，示範綁定）。
  - `mvvm-c`（UIKit）→ 入口換成 `AppCoordinator` 驅動的最小 2 畫面 list → detail，各畫面自帶 ViewModel。
- **`false`** → 只出文件＋Mermaid 架構圖，主畫面退回 v0.1 的樸素畫面，**不生空資料夾**。

它是**專案屬性**而非執行選項（描述「這專案生成時含不含範例」，同 `quality.swiftlint`），所以進 `scaffold.yml` 而不是 CLI flag（§4 原則）。

### 3.4 生成專案的文件

生成專案的 README 加入：

- **Mermaid 關係圖**：依 `(pattern, interface)` 給一段靜態圖——MVVM 為 View → ViewModel →（Model），MVVM-C 再加 Coordinator → ViewControllers。GitHub 直接渲染成圖，純文字環境仍可讀。
- **檔案結構圖**維持現有 ASCII tree。

`includeExample: false` 時圖描述的是「這個 pattern 的意圖結構」，作為指南；`true` 時圖與實際生成的檔案一致。兩張圖各司其職，都只靠靜態模板 + `{{NAME}}` 代換，不新增機制。

---

## 4. `scaffold.yml` 與 Schema 變更

- 新增 `architecture.includeExample: Bool`，預設 `true`。
- **`schemaVersion` 維持 `1`。** 新增的是選填、有預設值的欄位，向後相容；0.x 無相容承諾也不做 migration（README），沒有 bump 的理由。
- `ArchitecturePattern` enum 值域不變（`minimal` / `mvvm` / `mvvm-c` / `clean` 早已保留，§5）。變的只是驗證層對 `mvvm` / `mvvm-c` 的裁決。
- **不新增 preset。** 架構走 `--config` 或 `new` 選擇；preset 維持只有 `ios-uikit` / `ios-swiftui` 兩個（皆 minimal）。

§18.2 的同步清單一併觸發：`includeExample` 要連動預設值、YAML 編解碼、驗證、JSON output、`Skills/.../references/configuration-schema.md` 與測試。

---

## 5. 驗證變更

沿用 v0.1 的純函式驗證（§6，不建 protocol／Resolver）。v0.2 的異動：

- **`XS0004` 收窄**：`mvvm` 與 `mvvm-c`（on UIKit）不再回報「架構不支援」；`clean` 仍回報。
- **新增 `XS0xxx`（能力邊界）**：`mvvm-c` 需要 UIKit——`mvvm-c × swiftui` 回報「這版還沒支援」。號碼實作時接續指定（如 `XS0009`）。
- **新增 `XS1xxx`（永遠不合法）**：`includeExample: true` 需要 pattern 有範例，配 `minimal` → 永遠不合法（`minimal` 沒有範例可生）。號碼實作時定（`XS12xx` 區段目前空著可用）。

§6.2 的不變式全數沿用：每條新規則要有**專屬**正反案例；`XS0xxx` 才可出現「in this version」，`XS1xxx` 不可；每個宣告的錯誤碼都必須至少能被某個設定觸發。

§15 的約束照做：**prompt 不內嵌任何相容性規則**，`mvvm-c × swiftui` 這種組合由 `new` 照收、交給 `validate` 判、再依 `issue.path` 重問，相容性邏輯仍只在驗證層一處。

---

## 6. `new` 指令

裁決記於 [ADR-0005](../adr/0005-interactive-new-command-separate-from-init.md)。

### 6.1 流程

```text
互動收集精選欄位 → 填 PartialProjectConfiguration
    → validate（不過 → 依 issue.path 重問那一題，迴圈到過）
    → plan → 顯示摘要 → 確認（--yes 跳過）
    → 走同一條 init pipeline：暫存區 → 原子搬移 → git → xcodegen
```

`init` 契約完全不動；`new` 只是在前面接一段互動收集，後段共用既有 `GenerationPlan` / `PlanExecutor` / `ProcessRunner`。

### 6.2 題組

只問高訊號欄位，其餘吃預設：

- `project.name`、`project.bundleIdentifier`（預設 `com.example.<name>`）
- `interface.primary`（uikit / swiftui）
- `architecture.pattern`（minimal / mvvm / mvvm-c）
- `architecture.includeExample`——**僅當 pattern ≠ minimal 才問**
- `environments`——只給「無（Debug/Release）」vs「標準三環境（development / staging / production）」；自訂環境生成後改 `scaffold.yml`

其餘（`deploymentTarget` 18.0、`languageMode` 6、`testing.unit` swift-testing…）走預設。

### 6.3 契約邊界

- **`130`（User cancelled）回歸**：`new` 過程 Ctrl-C → exit 130。
- **`--yes`**：跳過最後「確認生成？」一步。
- **`new --output json` → exit 2**：json 禁止互動（§11.3），兩者互斥。
- **非 TTY（管線／CI）→ exit 2**：訊息導向 `init --config/--preset`。
- `new` 共用 `init` 的執行 flag（`--destination` / `--skip-git` / `--skip-generate` / `--force` / `--validate-build`）；只有*設定*是互動收集。

### 6.4 測試

以**注入輸入**（不真的開 TTY）驅動 prompt 的 unit test：驗證題組順序、`includeExample` 只在 pattern≠minimal 出現、驗證迴圈會重問出問題的那一題、Ctrl-C → 130、非 TTY／json 的守衛。互動機制（`readLine` 式或選單式）是實作者的決定，只要可被注入輸入測試。

---

## 7. 測試策略

沿用 v0.1 三層（§12）。v0.2 的增量：

- **契約 snapshot**：新增組合的檔案清單、`project.yml`、JSON output。`off` variant 以 snapshot 覆蓋（主畫面 code ≈ minimal，差異在文件）。任何產出物不得殘留未代換的變數標記——這條沿用。
- **E2E（每次 push）5 組**：
  - full build/test：`uikit-mvvm`(on)、`swiftui-mvvm`(on)、`uikit-mvvm-c`(on)
  - 保留 v0.1：`uikit-minimal`、`swiftui-minimal`
  - `off` variant 不進 full E2E（主畫面等同 minimal，已被涵蓋）。
- 公開 runner 免費不計量（§12.1），5 組仍在合理範圍。

---

## 8. Skill 與文件同步

- `Skills/.../references/configuration-schema.md`：補 `architecture.includeExample`、`mvvm` / `mvvm-c` 的合法性與矩陣。
- `SKILL.md` 工作流程不變（Skill 是 AI 路線、寫 `scaffold.yml` 呼叫 `init`，不走互動 `new`）。
- `CONTEXT.md`：補用語——`PartialProjectConfiguration`（§15 已引用但未定義）、Coordinator、以及「範例」在 overlay 語境下的定義。新增用語前先讀 `CONTEXT.md`（§18.2）。
- `README.md`：`new` 進指令表與用法；`architecture` 段補 `includeExample`。

---

## 9. 執行順序

| Milestone | 內容 | 驗收 | 依賴 |
|---|---|---|---|
| v0.2-M1 | Schema：`includeExample` 欄位；`mvvm` / `mvvm-c` 合法性；新驗證規則 | 每條規則正反案例；`XS0xxx` / `XS1xxx` 語氣正確；YAML round-trip | — |
| v0.2-M2 | MVVM overlay 產碼：`mvvm × {uikit, swiftui}` 範例＋Mermaid/ASCII 文件 | 契約 snapshot＋E2E（uikit-mvvm、swiftui-mvvm） | M1 |
| v0.2-M3 | `mvvm-c × uikit` overlay：`AppCoordinator`＋2 畫面 list→detail | 契約 snapshot＋E2E（uikit-mvvm-c） | M1 |
| v0.2-M4 | `includeExample=false` 路徑：純文件＋Mermaid 圖，跨組合 | `off` variant 契約 snapshot | M2、M3 |
| v0.2-M5 | `xscaffold new`：互動、驗證迴圈、`--yes`、`130`、TTY／json 守衛 | 走完一次人類路線；prompt 以注入輸入 unit test | M1（可與 M2/M3 並行） |
| v0.2-M6 | Skill schema reference、CONTEXT.md、ADR/README/計畫同步 | schema reference 對得上 schema；文件一致 | M1–M5 |

### 9.1 v0.2 Definition of Done

```bash
xscaffold new                 # 互動選 swiftui + mvvm + 含範例
xscaffold init DemoC --config demo.yml   # pattern: mvvm-c, interface: uikit, includeExample: true
```

- `new` 走完互動並生出一個能 `open`、`build`、`test` 的專案。
- `mvvm-c × uikit` 生成的專案含 `AppCoordinator` 與 2 畫面流程，`build`/`test` 全綠。
- `mvvm-c × swiftui` 被 `validate` 以 `XS0xxx` 擋下，訊息含「in this version」。
- `includeExample: true` 配 `minimal` 被 `validate` 以 `XS1xxx` 擋下。
- E2E 5 組在 CI 全綠。

---

## 10. 明確排除的範圍

以下不在 v0.2：

- **macOS 全線**（SwiftUI / AppKit variant）——延到 v0.3。
- **MVVM-C 的 SwiftUI 版**（router + `NavigationStack(path:)`）——`XS0xxx`，未定何時做。
- **Clean 架構**——仍 `XS0004`；它才是可能逼出「overlay 升級成 XcodeGen spec 變換器」的案例，屆時再開 ADR。
- **Architecture preset**（如 `ios-uikit-mvvm`）——架構走 `--config` 或 `new`。
- **`new` 的欄位 flag**（如 `new --interface swiftui`）——要非互動就走 `init`；避免 `new` 與 `init` 語意重疊。

---

## 11. 決策摘要

```text
主軸          MVVM/MVVM-C overlay + 互動式 new
macOS         延到 v0.3
MVVM          UIKit + SwiftUI，取代主畫面的具體範例
MVVM-C        UIKit only；mvvm-c×swiftui → XS0xxx
overlay 形態   具體範例，單一 app target，不動 XcodeGen spec（ADR-0004）
範例開關       architecture.includeExample（scaffold.yml，預設 true）
              off → 只出文件＋Mermaid 圖，不生空資料夾
文件          Mermaid 關係圖 + ASCII 檔樹
new           新指令，init 契約不動（ADR-0005）；prompt 不含相容規則
              130 / --yes 回歸；json 與非 TTY → exit 2
驗證          XS0004 收窄；新增 mvvm-c 需 UIKit（XS0xxx）、includeExample+minimal（XS1xxx）
測試          契約 snapshot 全組合；E2E 5 組
schemaVersion 維持 1
```
