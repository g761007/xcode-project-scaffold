# xcode-project-scaffold v0.3 開發計劃

> 目標讀者：專案擁有者、Code Agent
> Repository：`xcode-project-scaffold`（public）
> CLI：`xscaffold`
> 核心契約：`scaffold.yml`
> 前一版：`v0.2.0`（見 `xcode-project-scaffold-plan-v0.2.md`）

本版承接 v0.2（五個指令、兩個 iOS variant、MVVM／MVVM-C overlay、互動式 `new` 已交付）。v0.3 只推**一條軸——platform**：把 `product.platform` 從「只有 iOS 有實體、macOS 回 `XS0001`」變成 **macOS 真的生得出可運作的專案**，一次交付 `macos-swiftui` 與 `macos-appkit` 兩個 variant。

用語以 `CONTEXT.md` 為準。範圍以外的邊界一律沿用 v0.1／v0.2 計劃與 `docs/adr/`。

---

## 1. 定位

定位不變：**只做 init，不管理既有專案**（[ADR-0001](../adr/0001-scaffold-yml-as-birth-certificate.md)）。v0.3 不觸碰這條邊界，只在既有邊界內把 *platform* 軸從 iOS 拓到 macOS。

這是 v0.1／v0.2 一路紀律的第三步：**一次只推一條軸**。

- v0.1 用 UIKit + SwiftUI 逼出 *interface* 軸的共用邊界。
- v0.2 深化 *architecture* 軸（overlay 升級成具體範例）並補 *human on-ramp*（`new`）。
- v0.3 推 *platform* 軸（iOS → macOS）。第二個平台會逼出 `Shared` 層裡真正跨平台的邊界——正如第二個 interface 逼出跨介面邊界（§4）。

schema 早為此備好料：`ApplePlatform.macOS`、`UIFramework.appKit`、`ApplicationLifecycle.appDelegate`、以及 `XS1001`／`XS1002`／`XS1103`／`XS0007` 的 macOS 下限值，v0.2 之前就已宣告但無人觸發。v0.3 讓它們轉活。

---

## 2. v0.3 支援範圍

| 維度 | v0.1 | v0.2 | **v0.3 新增** | 之後 |
|---|---|---|---|---|
| Platform | iOS | iOS | **macOS** | — |
| Interface | UIKit、SwiftUI | UIKit、SwiftUI | **AppKit** | — |
| Architecture | Minimal | +MVVM、MVVM-C | MVVM 鋪到 macOS | Clean |
| MVVM 適用 | — | UIKit + SwiftUI（iOS） | **+ macOS SwiftUI、macOS AppKit** | — |
| MVVM-C 適用 | — | UIKit only（iOS） | 維持 UIKit only（等於 iOS only） | AppKit coordinator（未定） |
| Product type | application | application | — | framework |
| Generator | XcodeGen | XcodeGen | — | Tuist |
| 建立方式 | `init`、Skill | `+new` | `new` 補平台題 | — |

**一次交付 macOS SwiftUI + AppKit 兩個 variant。** 理由同 v0.1 §2：只有一個 variant 時，Shared 層是未經驗證的猜測。放到 platform 軸上——`macos-swiftui` 逼問「SwiftUI variant 到底跨不跨平台」，`macos-appkit` 才是真正的新介面（`app-delegate` lifecycle、無 scene、選單列、視窗管理）。少了 AppKit，「macOS 支援」是半套，且會把 v0.3 的實質內容推給 v0.4。

**Clean、Tuist、framework、AppKit coordinator 不進 v0.3**（§14）——一次只推一條軸。

---

## 3. macOS 平台軸

### 3.1 兩個新 variant

依 `CONTEXT.md`，Variant = platform × language × interface，各 Variant **不共用原始碼**。macOS 兩個 variant 因此是全新的兩包，與 iOS 同名 interface 不共用：

```text
Templates/Variants
├── ios-uikit       （v0.1）
├── ios-swiftui     （v0.1）
├── macos-swiftui   （v0.3 新）App + ContentView，SwiftUI 生命週期
└── macos-appkit    （v0.3 新）AppDelegate + 程式碼建視窗與選單列（§5）
```

Variant 目錄名維持 `<platform>-<interface>`，直接由 schema raw value 組成，不需對照表。

### 3.2 Lifecycle 用推導，不新增問題

Lifecycle 由 `(platform, interface)` 推導，非使用者選擇：

| Variant | Lifecycle | 說明 |
|---|---|---|
| `macos-swiftui` | `swiftui` | 同 iOS SwiftUI |
| `macos-appkit` | `app-delegate` | macOS **沒有 scene**，因此只有 `AppDelegate`，無 SceneDelegate |

`ApplicationLifecycle.appDelegate` 與 `XS1103`（`app-delegate` 需要 AppKit）早已備好；v0.3 讓它們轉活。`new` 不新增 lifecycle 題（§10）。

### 3.3 deploymentTarget 預設改為依平台解析

`product.deploymentTarget` 的預設在 v0.1／v0.2 一律填 `"18.0"`。那是 iOS 的值，在 macOS 無意義（macOS 沒有 18.x）。v0.3 讓預設**依平台解析**：

| Platform | 預設 deploymentTarget | XS0007 靜態下限 |
|---|---|---|
| iOS | `18.0`（不變） | 15.0 |
| macOS | `15.0`（Sequoia，配對 iOS 18 的同期釋出） | 11.0 |

XS0007 的下限維持 §6.1 的靜態值（取自 SDK 自報的 `RecommendedDeploymentTarget`），不去查詢當前機器裝了什麼——那是 `doctor` 的職責。使用者明確填 `deploymentTarget` 時照用其值。

---

## 4. Shared 層跨平台邊界（macOS 逼出的核心工作）

現況：`Templates/Shared/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` 是 **iOS 專屬**（`"platform": "ios"`，單張 1024×1024 universal）。macOS 用不了這份 AppIcon——它需要 mac idiom 的圖檔。這正是第二個平台該逼出的共用邊界。

**裁決：`AppIcon.appiconset` 下放到 Variant 層，依平台各帶一份；`AccentColor` 與 asset catalog 外殼（`Assets.xcassets/Contents.json`）維持在 Shared。**

- **AppIcon 是平台專屬**：iOS 與 macOS 的 idiom／尺寸不同，屬於 Variant。
- **AccentColor 是平台中性**：`AccentColor.colorset` 兩平台通用，留 Shared。
- **生成輸出對 iOS 不變**：這是**模板來源的重整**，不是輸出改變。合成後 iOS variant 的 `Resources/Assets.xcassets/AppIcon.appiconset` 內容與路徑逐字不變，既有 iOS 契約 snapshot **不應改動**（若改動即為回歸訊號）。

`Resources/` 仍放**真的資產目錄**而非 `.gitkeep`（v0.1 §7.2 的理由不變：`project.yml` 的 `sources` 列了 `Resources`，目錄不存在時 `xcodegen generate` 會失敗）。

---

## 5. AppKit variant 的設計

裁決記於 [ADR-0006](../adr/0006-appkit-built-programmatically.md)。

**純程式碼建 UI 與選單列，零 storyboard、零 XIB。**

- 無 `Main.storyboard`
- 無 `MainMenu.xib`——選單列以 `NSMenu` 在 `AppDelegate` 程式碼建立
- 主視窗以 `NSWindow` / `NSWindowController` 程式碼建立並顯示
- `NSApplicationDelegate` 為進入點（`@main` 或 `NSApplication.shared` + `applicationDidFinishLaunching`）

理由延續 v0.1 §8：選 XcodeGen 的核心動機是避開機器產 XML 的 merge conflict，而 `MainMenu.xib` 與 `Main.storyboard` 是一模一樣的問題——同樣機器產、同樣會在多人改動時炸開。前門擋了後門開沒有意義。代價：比接受 `MainMenu.xib` 多寫一段建立標準選單列的樣板碼；ADR-0006 記錄這筆交易。

Xcode 26.4 的內建 AppKit 樣板仍以 `MainMenu.xib` + `NSApplicationMain` 起手；本專案刻意不沿用，改走程式碼路線。

---

## 6. 架構 overlay 在 macOS

沿用 v0.2 的 overlay 機制（[ADR-0004](../adr/0004-architecture-overlay-generates-a-concrete-example.md)：具體範例、取代主畫面、不變換 XcodeGen spec、不新增 target、不生抽象基底層）。v0.3 只擴充適用矩陣：

| | ios-uikit | ios-swiftui | **macos-swiftui** | **macos-appkit** |
|---|---|---|---|---|
| `minimal` | ✅ v0.1 | ✅ v0.1 | ✅ 新 | ✅ 新 |
| `mvvm` | ✅ v0.2 | ✅ v0.2 | ✅ **新** | ✅ **新** |
| `mvvm-c` | ✅ v0.2 | `XS0009` | `XS0009` | `XS0009` |

- **MVVM 鋪滿兩個 macOS variant**：MVVM 與介面／平台無關，可乾淨落地——macOS SwiftUI 等同 iOS SwiftUI 的 View + 具體 ViewModel；macOS AppKit 為 `NSViewController` + 具體 ViewModel。直接複用 v0.2 蓋好的 overlay。若 macOS 只給 minimal，overlay 就退回「只在 iOS 驗證過」的未驗證邊界。
- **MVVM-C 維持 UIKit only**：coordinator 的存在理由（v0.2 §3.2）是解 UIKit 命令式導航（`pushViewController`）的耦合。AppKit 也有命令式導航，但慣例完全不同（NSWindowController／NSSplitViewController／視窗驅動）——那是一份**全新設計**，該自己開 ADR，不搭 v0.3 的順風車。macOS 兩個 variant 的 mvvm-c 一律由 `XS0009` 擋（能力邊界，門留給日後的 AppKit coordinator，見 §14）。

macOS SwiftUI 的 mvvm-c 與 iOS SwiftUI 同樣落在 `XS0009`（SwiftUI router 版未定何時做）。

生成專案 README 的 **Mermaid 關係圖**與 **ASCII 檔樹**沿用 v0.2 §3.4：依 `(pattern, interface)` 給靜態圖，只靠 `{{NAME}}` 代換，不新增機制。

---

## 7. `scaffold.yml` 與 Schema 變更

v0.3 **不新增任何 `scaffold.yml` 欄位**——`product.platform` 早已是一等欄位（值 `ios` / `macos`），v0.3 只讓 `macos` 由驗證放行。變的是：

- **預設值解析改為依平台**：`deploymentTarget` 依 `product.platform` 解析（§3.3）；lifecycle 依 `(platform, interface)` 推導（§3.2）。連動 `ConfigurationDefaults`。
- **`ArchitecturePattern` / `UIFramework` / `ApplePlatform` enum 值域不變**——早已保留完整值域，變的只是驗證裁決。
- **`schemaVersion` 維持 `1`**：narrow 既有驗證 + 依平台解析預設，向後相容；0.x 無相容承諾也不做 migration（README），沒有 bump 的理由。與 v0.2 一致。

§18.2 的同步清單觸發：依平台解析的預設值要連動預設值填充、驗證、JSON output、`Skills/.../references/configuration-schema.md` 與測試。

---

## 8. 驗證變更

沿用 v0.1 的純函式驗證（§6，不建 protocol／Resolver）。v0.3 的異動：

- **`XS0001` 收窄 → 成死碼 → 移除**：`macos` 不再回報「平台不支援」。`ApplePlatform` 只有 `ios`／`macos` 兩個 case，兩者放行後 **`XS0001` 再無任何設定能觸發**（不存在的平台值在解碼層就被擋下、走 exit 3 config parsing failure，不進驗證層）。依 §6.2 不變式 3 與死碼先例（`XS0002`、舊 `XS1201` 都因無觸發者而移除），**`XS0001` 一併移除**。
- **`XS0006` 收窄 → 成死碼 → 移除**：`appkit` 不再回報「介面不支援」。`UIFramework` 三個 case（`uikit`／`swiftui`／`appkit`）放行後皆合法，`XS0006` 同樣無觸發者——**同 `XS0001` 處置，移除**。
- **已定案（A：移除）**：`XS0001`／`XS0006` 隨 macos／appkit 放行後即移除，依死碼先例（`XS0002`、舊 `XS1201`）。替代方案 B（保留兩碼並在 enum 反手預留一個未來平台／介面如 `tvos`／`visionos` 當觸發者）評估後不採——擴充 enum 值域是投機性決定，留到未來真的要加平台／介面時再一併計劃。
- **`XS0009`（`coordinatorRequiresUIKit`）訊息改寫**：由「MVVM-C is not supported for SwiftUI in this version.」改為涵蓋 AppKit 的「**MVVM-C is only available on UIKit in this version.**」。它現在同時擋 `mvvm-c × swiftui` 與 `mvvm-c × {macos-appkit}`。語氣維持能力邊界（「in this version」合法）：SwiftUI 有 router 對應物、AppKit 有 coordinator 對應物，兩者都是「還沒做」而非「永遠不行」。golden 訊息表更新。
- **`XS1001`／`XS1002`／`XS1103` 轉活**：macOS 進來後，`UIKit requires iOS`（`macos-uikit`）、`AppKit requires macOS`（`ios-appkit`）、`app-delegate requires AppKit` 這三條永久規則第一次有合法途徑被觸發，正好補上 §6.2 不變式 3 的空缺。
- **`XS0007` macOS 下限**：以 macOS 11.0 靜態值判斷（§3.3）。

**§6.2 不變式全數沿用**：每條受影響規則的正反案例要更新；`XS0xxx` 才可出現「in this version」，`XS1xxx` 不可；每個宣告的錯誤碼都必須至少能被某個設定觸發（這一版特別牽動 `XS0001`／`XS0006` 的去留，見上）。

§15 的約束照做：**prompt 不內嵌任何相容性規則**——`new` 照收 `ios-appkit`、`macos-uikit` 這類組合，交給 `validate` 判、再依 `issue.path` 重問（§10）。

---

## 9. Preset 變更

現況：`Preset` 只帶 `interface` 一個欄位（`ios-uikit` / `ios-swiftui`，皆 minimal）。v0.3：

- **`Preset` 多帶 `platform`**：這是 `Preset.swift` 註解自陳「當一個 preset 需要說的比 schema 預設多時，這筆交易再做一次」的時刻。
- **新增兩個 macOS preset**：

  | preset | platform | interface | 摘要 |
  |---|---|---|---|
  | `macos-swiftui` | macos | swiftui | macOS app, SwiftUI, App lifecycle |
  | `macos-appkit` | macos | appkit | macOS app, AppKit, programmatic AppDelegate |

- 四個 preset 皆 minimal；架構仍走 `--config` 或 `new`（不加 architecture preset，§14）。
- `bundleIdentifier` 推導（`com.example.<name>`）不變。lifecycle 由 preset 的 `(platform, interface)` 推導（§3.2）。

---

## 10. `new` 指令變更

沿用 v0.2 的 `new`（[ADR-0005](../adr/0005-interactive-new-command-separate-from-init.md)：獨立於 `init`、prompt 不含相容規則、驗證迴圈重問）。v0.3 的增量：

- **新增「平台」為第一題**：`product.platform`（iOS / macOS）。`PartialProjectConfiguration` 因此**多一個 `platform` 欄位**。
- **介面選項維持平鋪**：`askInterface` 一次給 UIKit / SwiftUI / AppKit 全部三個，**不依平台過濾**——過濾就是把相容規則塞進 prompt（違反 §15）。選了不合的組合（`ios-appkit`、`macos-uikit`）由 `validate` 以 `XS1001`／`XS1002` 擋下，再依 `issue.path` 重問介面那一題。
- **驗證迴圈路由擴充**：`reask(for:)` 的 `switch` 補 `product.platform` → 重問平台；`interface.lifecycle` 已在既有 case 內（重問介面即重解 lifecycle）。
- **其餘題組不變**：架構、`includeExample`（僅 pattern≠minimal 才問）、environments 沿用 v0.2。
- **契約邊界不變**：`--yes`、`130`、`new --output json` → exit 2、非 TTY → exit 2、共用 `init` 執行 flag。

### 10.1 為什麼平台不從介面反推

有人會問「選 AppKit 就一定是 macOS，何必問平台」。但 SwiftUI 兩個平台都有，反推不出平台；把平台當第一題、介面平鋪，才讓 `(platform, interface)` 的所有組合都由**同一處**（validate）裁決，prompt 不必知道任何配對規則。

---

## 11. 測試策略

沿用 v0.1／v0.2 三層（§12）。v0.3 的增量：

- **契約 snapshot**：新增 `macos-swiftui` / `macos-appkit` 各 `{minimal, mvvm}` 的檔案清單、`project.yml`、JSON output。§4 的 AppIcon 下放**不得改動既有 iOS snapshot**（改動即回歸）。任何產出物不得殘留未代換的變數標記——沿用。
- **E2E（每次 push）9 組**：
  - v0.1／v0.2 保留 5 組：`ios-uikit-minimal`、`ios-swiftui-minimal`、`ios-uikit-mvvm`、`ios-swiftui-mvvm`、`ios-uikit-mvvm-c`。
  - **新增 4 組**：`macos-swiftui-minimal`、`macos-swiftui-mvvm`、`macos-appkit-minimal`、`macos-appkit-mvvm`。
  - macOS 的 E2E destination 用 `platform=macOS`（無模擬器，直接跑在 runner 的 mac 上）；iOS 維持明確 udid／OS（§12.2 的可重現性理由不變）。
  - `off` variant（`includeExample: false`）不進 full E2E，只以 snapshot 覆蓋（主畫面等同 minimal）。
- 公開 runner 免費不計量（§12.1），9 組仍在合理範圍。
- **`new` 平台題以注入輸入 unit test**：斷言平台為第一題、`ios-appkit`／`macos-uikit` 會被驗證擋下並重問對的那一題、平台欄位正確填入 `PartialProjectConfiguration`。不真的開 TTY。

---

## 12. Skill 與文件同步

- `Skills/.../references/configuration-schema.md`：補 `product.platform: macos`、AppKit 介面、macOS 的 deploymentTarget 預設、以及更新後的 `(platform, interface)` 相容矩陣。
- `SKILL.md` 工作流程不變（AI 路線寫 `scaffold.yml` 呼叫 `init`，不走 `new`）。
- `CONTEXT.md`：Variant 定義已涵蓋 `macos-appkit`；補「Shared 層哪些資產跨平台、哪些下放 Variant」的用語界定（§4）；AppKit 選單列以程式碼建立一節指向 ADR-0006。新增用語前先讀 `CONTEXT.md`（§18.2）。
- `README.md`：支援矩陣加 macOS 列與 AppKit；preset 表加兩個 macOS preset；`new` 平台題；macOS deploymentTarget 預設。
- `CHANGELOG.md`：`0.3.0` 段。

---

## 13. 執行順序

| Milestone | 內容 | 驗收 | 依賴 |
|---|---|---|---|
| v0.3-M1 | Schema／驗證／依平台預設：放行 `macos`、`appkit`；`XS0009` 訊息改寫；`XS1001/1002/1103` 轉活；`XS0001/XS0006` 去留；deploymentTarget 與 lifecycle 依平台解析 | 每條受影響規則正反案例；`XS0xxx`／`XS1xxx` 語氣正確；死碼處置；預設值依平台正確 | — |
| v0.3-M2 | Shared 邊界：`AppIcon.appiconset` 下放 Variant、`AccentColor` 留 Shared；合成機制 | 既有 iOS 契約 snapshot **不變**；macOS AppIcon 可用 | M1 |
| v0.3-M3 | `macos-swiftui` variant（minimal + mvvm）＋ Mermaid／ASCII 文件 | 契約 snapshot ＋ E2E（macos-swiftui-minimal、macos-swiftui-mvvm） | M1、M2 |
| v0.3-M4 | `macos-appkit` variant（minimal + mvvm）：程式碼建 AppDelegate／視窗／NSMenu，零 XIB（ADR-0006） | 契約 snapshot ＋ E2E（macos-appkit-minimal、macos-appkit-mvvm） | M1、M2 |
| v0.3-M5 | `new` 平台題 + `PartialProjectConfiguration.platform`；兩個 macOS preset（`Preset.platform`） | 平台題以注入輸入 unit test；`init --preset macos-*` 生得出專案（生成驗收依賴 M3／M4） | M1（互動邏輯）；生成端 M3、M4 |
| v0.3-M6 | Skill schema reference、CONTEXT.md、ADR/README/CHANGELOG/計畫同步；E2E 矩陣補到 9 組 | schema reference 對得上 schema；文件一致；CI 9 組全綠 | M1–M5 |

依賴：M1 先行 → M2 依賴 M1 → M3／M4 依賴 M2（可並行）→ M5 依賴 M1（互動邏輯可與 M2–M4 並行，生成驗收待 M3／M4）→ M6 收尾。

### 13.1 v0.3 Definition of Done

```bash
xscaffold new                                  # 互動選 macOS + AppKit + minimal
xscaffold init MacDemo --preset macos-swiftui  # macOS SwiftUI minimal
xscaffold init MacMVVM --config macos-mvvm.yml # platform: macos, interface: appkit, pattern: mvvm
```

- `new` 走完互動（含平台題），生出一個能 `open`、`build`、`test` 的 macOS 專案。
- `macos-appkit` 生成的專案零 storyboard、零 XIB，程式碼建視窗與選單列，`build`／`test` 全綠。
- `macos-swiftui` 與 `macos-appkit` 的 `mvvm` 各生出取代主畫面的具體範例，`build`／`test` 全綠。
- `mvvm-c × macos-*` 被 `validate` 以 `XS0009` 擋下，訊息含「in this version」。
- `ios-appkit`／`macos-uikit` 被 `validate` 以 `XS1002`／`XS1001` 擋下。
- 既有 iOS 契約 snapshot 不變。
- E2E 9 組在 CI 全綠。

---

## 14. 明確排除的範圍

以下不在 v0.3：

- **AppKit coordinator（`mvvm-c × macos-appkit`）**——`XS0009`，門留著；視窗／split-view 驅動的 coordinator 是全新設計，屆時開新 ADR。
- **MVVM-C 的 SwiftUI 版**（router + `NavigationStack(path:)`）——`XS0009`，未定何時做。
- **Clean 架構**——仍 `XS0004`；它才是可能逼出「overlay 升級成 XcodeGen spec 變換器」的案例，屆時再開 ADR。
- **Tuist generator**——仍 `XS0005`；屬換後端，可自成一版。
- **`framework` product type**——仍 `XS0003`。
- **Architecture preset**（如 `macos-appkit-mvvm`）——架構走 `--config` 或 `new`。
- **`new` 的欄位 flag**（如 `new --platform macos`）——要非互動就走 `init`。
- **Package Registry / Feature Provider**——v0.1 §14 標「延後至 v0.3 之後再評估」；本版不評估，維持延後。
- **Homebrew tap／穩定性承諾／預編 binary**——留到 1.0 之後。

---

## 15. 決策摘要

```text
主軸          新增 macOS 平台軸（一次做滿 SwiftUI + AppKit）
platform      macos 由驗證放行；一次交付 macos-swiftui + macos-appkit 兩個 variant
lifecycle     推導：macos-swiftui→swiftui、macos-appkit→app-delegate（無 scene）
deploymentTarget 依平台解析：iOS 18.0（不變）、macOS 15.0；XS0007 下限 macOS 11.0
Shared 邊界    AppIcon 下放 Variant（平台專屬），AccentColor 留 Shared；iOS 輸出不變
AppKit variant 零 storyboard、零 XIB，程式碼建視窗與 NSMenu 選單列（ADR-0006）
架構 overlay   MVVM 鋪滿兩個 macOS variant；MVVM-C 維持 UIKit only（macOS 一律 XS0009）
驗證          XS0001/XS0006 收窄（死碼處置）；XS0009 訊息改涵蓋 AppKit；XS1001/1002/1103 轉活
preset        新增 macos-swiftui、macos-appkit（Preset 多帶 platform）；共四個，皆 minimal
new           新增平台題（第一題）；介面平鋪、validate 裁決；契約邊界不變
測試          契約 snapshot 全新組合；E2E 5→9 組（macOS 用 platform=macOS）
schemaVersion 維持 1（無新欄位，僅放行既有值 + 依平台解析預設）
```
