# xcode-project-scaffold 開發計劃（v0.1 收斂版）

> 目標讀者：專案擁有者、Code Agent
> Repository：`xcode-project-scaffold`（public）
> CLI：`xscaffold`
> 核心契約：`scaffold.yml`
> 前一版：`xcode-project-scaffold-plan.original.md`

本版是原始計劃書經過一輪逐項檢視後的收斂結果。原始版本的範圍約為本版的三倍，且包含數個互相矛盾的驗收條件。被刪除的內容列在 §14，刪除理由多數記錄在 `docs/adr/`。

用語以 `CONTEXT.md` 為準。

---

## 1. 定位

> 用一份可版控的設定，可重現地建立新的 Xcode 專案。

一句話能講完的邊界，就是這個工具的邊界。它**只做 init**：

- 不管理已存在的專案
- 不重新生成
- 不做 inspect / import / add
- 不維護檔案所有權

理由見 [ADR-0001](../adr/0001-scaffold-yml-as-birth-certificate.md)。

### 1.1 三種使用方式

```text
xscaffold init --preset ios-uikit MyApp        非互動、預設值
xscaffold init --config scaffold.yml           宣告式
Skill → scaffold.yml → validate → plan → init  AI 路線
```

互動式 prompt 不在 v0.1，見 §13。

### 1.2 版本承諾

**0.x 階段不對外承諾 `scaffold.yml` schema 與 CLI contract 的相容性。** 這一點必須明文寫在 README 第一段。Repository 從第一天就是 public，但 public 不等於穩定。

Homebrew tap、issue 回報流程、模板相容性政策留到 1.0 之後。

---

## 2. v0.1 支援範圍

| 維度 | v0.1 | 之後 |
|---|---|---|
| Platform | iOS | macOS |
| Language | Swift | — |
| Interface | UIKit、SwiftUI | AppKit |
| Architecture | Minimal | MVVM、MVVM-C、Clean |
| Product type | application | framework |
| Generator | XcodeGen | Tuist |
| Deployment target | iOS 18.0（預設） | — |
| Swift 語言模式 | 6（strict concurrency） | — |

**Objective-C 與 Mixed 不在任何版本的 init 路線上。** 2026 年不會有人用 scaffold 工具開一個全新的 Objective-C 專案；Objective-C 的真實存在形式是維護既有專案，而那已經被 §1 的邊界排除。

**UIKit 與 SwiftUI 兩個 variant 在 v0.1 同時交付。** 只有一個 variant 的時候，模板的 Shared 層是未經驗證的猜測；第二個 variant 才會逼出真正的共用邊界。

---

## 3. Repository 結構

```text
xcode-project-scaffold
├── Package.swift
├── README.md
├── CONTEXT.md
├── Makefile
├── LICENSE
│
├── Sources
│   ├── ScaffoldSchema          零副作用，不得碰檔案系統或子行程
│   │   ├── ProjectConfiguration.swift
│   │   ├── Enums.swift
│   │   ├── ConfigurationDefaults.swift
│   │   └── ValidationIssue.swift
│   │
│   ├── ScaffoldCore
│   │   ├── Validation
│   │   ├── Templates
│   │   ├── XcodeGen
│   │   ├── Planning
│   │   ├── Generation
│   │   └── System
│   │
│   └── xscaffold
│       ├── XScaffold.swift
│       └── Commands
│           ├── InitCommand.swift
│           ├── ValidateCommand.swift
│           ├── PlanCommand.swift
│           └── DoctorCommand.swift
│
├── Templates
│   ├── Shared
│   ├── Variants
│   │   ├── ios-uikit
│   │   └── ios-swiftui
│   └── Architectures
│       └── minimal
│
├── Presets
│   ├── ios-uikit.yml
│   └── ios-swiftui.yml
│
├── Skills
│   └── xcode-project-scaffold
│       ├── SKILL.md
│       └── references
│           └── configuration-schema.md
│
├── docs
│   └── adr
│
└── Tests
    ├── ScaffoldSchemaTests
    ├── ScaffoldCoreTests
    ├── ContractSnapshotTests
    └── IntegrationTests
```

### 3.1 為什麼是三個 target

只有一條邊界是真的：`ScaffoldSchema` 必須零副作用。它是被 `scaffold.yml`、JSON output 與 Skill 共同消費的契約，需要編譯器保證它永遠碰不到檔案系統與子行程。

其餘職責（驗證、模板、生成、系統呼叫）在 v0.1 尚無經過驗證的邊界，先合併在 `ScaffoldCore`。SwiftPM 每個跨 target 呼叫都需要 `public`，過早切割等於在不知道邊界的時候固化介面。日後要拆只是搬檔案加 `public`。

### 3.2 相依方向

```text
xscaffold  →  ScaffoldCore  →  ScaffoldSchema
```

外部相依：`swift-argument-parser`、`Yams`。**不相依 XcodeGen 函式庫**，理由見 [ADR-0002](../adr/0002-build-project-yml-from-swift-types.md)。

---

## 4. `scaffold.yml`

`scaffold.yml` **只描述專案本身，不描述這次執行要做什麼**。「當初生成時有沒有跑 xcodegen」不是這個專案的屬性；那類設定一律是 CLI flag。

```yaml
schemaVersion: 1

project:
  name: MyApp
  organizationName: My Company
  bundleIdentifier: com.example.myapp

product:
  platform: ios
  type: application
  deploymentTarget: "18.0"

language:
  primary: swift
  languageMode: "6"

interface:
  primary: uikit                        # uikit | swiftui
  lifecycle: app-delegate-scene-delegate

architecture:
  pattern: minimal

generator:
  type: xcodegen

environments: []                        # 空陣列 = 只有 Debug / Release

quality:
  swiftlint: true
  swiftformat: true

testing:
  unit: swift-testing                   # swift-testing | xctest | none

git:
  defaultBranch: main
```

`environments` 展開後：

```yaml
environments:
  - name: development
    configuration: Debug
    bundleIdentifierSuffix: .dev
    displayNameSuffix: " Dev"
  - name: staging
    configuration: Staging
    bundleIdentifierSuffix: .stg
    displayNameSuffix: " STG"
  - name: production
    configuration: Release
```

### 4.1 已知的欄位設計決定

- `language.languageMode` 對應 Xcode 的 `SWIFT_VERSION`。它是**語言模式**，合法值只有 `5` 與 `6`（實測 `swiftc -swift-version` 接受 `4` / `4.2` / `5` / `6`），**不是**編譯器版本。填 `"6.3.1"` 會直接編譯失敗。
- 只保留 `bundleIdentifier` 這個明確值，不設 `organizationIdentifier`。後者留給日後互動式 prompt 當推導輔助，不進 schema。
- `interface.secondary` 不存在。v0.1 不支援混用。

---

## 5. Schema 核心型別

Enum **保留完整值域**，即使 v0.1 不支援。這樣 YAML 能乾淨解析，再由驗證層回報「這個版本還沒支援」，而不是丟出難懂的 Codable 錯誤。這也是 `XS0xxx` 錯誤類別存在的理由。

```swift
public enum ApplePlatform: String, Codable, CaseIterable, Sendable {
    case iOS = "ios"
    case macOS = "macos"                  // v0.1 → XS0001
}

public enum ProductType: String, Codable, CaseIterable, Sendable {
    case application
    case framework                        // v0.1 → XS0003
}

// Objective-C is absent on purpose, and this is the one place where the
// "keep the full domain" rule does not apply. macOS and Tuist are coming, so
// "not supported in this version" is honest for them; Objective-C is not
// coming at all (§2), so the same wording would mislead. `objective-c`
// therefore fails as an unrecognised value, listing `swift` as the only option.
public enum ProgrammingLanguage: String, Codable, CaseIterable, Sendable {
    case swift
}

public enum SwiftLanguageMode: String, Codable, CaseIterable, Sendable {
    case v5 = "5"
    case v6 = "6"
}

public enum UIFramework: String, Codable, CaseIterable, Sendable {
    case uiKit = "uikit"
    case swiftUI = "swiftui"
    case appKit = "appkit"                // v0.1 → XS0006
}

public enum ApplicationLifecycle: String, Codable, CaseIterable, Sendable {
    case swiftUI = "swiftui"
    case appDelegate = "app-delegate"     // AppKit only; macOS has no scenes
    case appDelegateSceneDelegate = "app-delegate-scene-delegate"
}

public enum ArchitecturePattern: String, Codable, CaseIterable, Sendable {
    case minimal
    case mvvm                             // v0.1 → XS0004
    case mvvmCoordinator = "mvvm-c"       // v0.1 → XS0004
    case clean                            // v0.1 → XS0004
}

public enum GeneratorKind: String, Codable, CaseIterable, Sendable {
    case xcodegen
    case tuist                            // v0.1 → XS0005
}

public enum UnitTestFramework: String, Codable, CaseIterable, Sendable {
    case swiftTesting = "swift-testing"
    case xctest
    case disabled = "none"                // named to stay clear of Optional.none
}
```

---

## 6. 驗證

不建 `CompatibilityRule` protocol，不建 Resolver，不建 `AvailableProjectOptions`。v0.1 的驗證是一個檔案裡的一組函式，回傳 `[ValidationIssue]`。規則超過約 15 條再考慮抽象。

```swift
public struct ValidationIssue: Codable, Sendable {
    public let severity: ValidationSeverity   // error | warning
    public let code: ValidationCode           // encodes as its raw value, e.g. "XS1001"
    public let message: String
    public let path: String?
    public let suggestion: String?
}
```

**驗證必須是純函式。** 不讀檔案、不呼叫子行程、不看環境。理由：同一份 `scaffold.yml` 在任何機器上都必須得到相同的驗證結果，否則 §1 的可重現性主張就有洞。凡是需要查詢「這台機器裝了什麼」的檢查，一律歸 `doctor`。

### 6.1 錯誤碼分兩群

這個區分很重要：使用者看到 macOS 被拒絕時，必須知道那是「還沒做」而不是「永遠不行」。

**`XS0xxx` — 能力邊界（這個版本還沒支援）**

```text
XS0001  Platform '<name>' is not supported in this version.
XS0003  Product type '<name>' is not supported in this version.
XS0004  Architecture '<name>' is not supported in this version.
XS0005  Generator '<name>' is not supported in this version.
XS0006  Interface '<name>' is not supported in this version.
XS0007  Deployment target '<v>' is below <min>, the minimum supported in this version.
```

`XS0007` 原本編為 `XS1303`，是錯的。它的下限是 **xscaffold 自己**的支援下限，不是 Apple SDK 的——日後模板支援更低版本時它就會降。可變 = 能力邊界。分在 `XS1xxx` 會告訴使用者「永遠不行」，但那不是事實。

**`XS1xxx` — 永遠不合法（`permanently-invalid`）**

分三個子區段：

```text
XS10xx  平台與介面組合
XS1001  UIKit is only available for iOS projects.
XS1002  AppKit is only available for macOS projects.

XS11xx  Lifecycle
XS1101  Lifecycle 'swiftui' requires SwiftUI as the primary interface.
XS1102  Lifecycle 'app-delegate-scene-delegate' requires UIKit as the primary interface.
XS1103  Lifecycle 'app-delegate' requires AppKit as the primary interface.

XS13xx  欄位值
XS1301  Bundle identifier '<id>' is not a valid reverse-DNS string.
XS1302  Deployment target '<v>' is not a version number.
XS1304  Project name is not usable as an Xcode target name.

XS14xx  環境
XS1401  Environment name '<name>' is used more than once.
XS1402  Build configuration '<name>' is used by more than one environment.
```

`XS1201`（Swift Testing 需要 Swift）已移除：`ProgrammingLanguage` 只有 `swift` 一個值，這條規則永遠不可能成立。與 `XS0002` 同樣理由。

`XS0007` 的下限是**靜態值**——iOS 15.0、macOS 11.0，取自 Xcode 26.4 SDK 自報的 `RecommendedDeploymentTarget`。它刻意不去查詢當前機器安裝了什麼；「你這台機器的 SDK 支不支援這個 deployment target」是 `doctor` 的職責。

一個格式錯誤的 deployment target **不會**同時回報 `XS0007`——讓使用者去追一個不存在的第二個問題是沒有意義的。

`XS1304`（專案名稱）是 M3 相對原始規格新增的一條。理由與其他兩項同級：一個會放行 `name: ""` 的驗證器不算驗證器，而專案名稱同時要當 Xcode target 名稱與目錄名稱，`""`、`"."`、`".."`、含 `/` 或控制字元的名稱都會在生成階段（M6）才炸開——那時錯誤訊息會指向檔案系統，與真正的原因相距甚遠。

`XS1301` 也涵蓋 `environments[].bundleIdentifierSuffix`：後綴會串接到 bundle identifier 上，只檢查基底等於只檢查一半。

### 6.2 必須測試的不變式

每條規則都必須有**專屬的**正反兩個測試案例——反例不得只靠「整份設定沒有任何問題」這種共用斷言，否則規則被誤刪時不會有人發現。

此外有四條跨規則的不變式：

1. 錯誤碼格式一律為 `XS` 加四位數字。（「不得重複」不需要測試：raw value 重複在 Swift enum 是編譯錯誤，寫成測試會是一條永遠不會失敗的裝飾。）
2. `code.category` 由 `switch` 明確指定，而非從前綴推導；測試驗證它與前綴一致，所以歸錯組的 case 是測試失敗而不是靜默重新分類。
3. **每個宣告的錯誤碼都必須至少能被某個設定觸發。** `XS0002` 與 `XS1201` 這兩個死碼能一路留在規格裡，正是因為少了這條。
4. **只有** `XS0xxx` 的訊息可以出現「in this version」。那是使用者判斷「還沒做」與「永遠不行」的唯一線索：一條 `XS1xxx` 若說了「in this version」，使用者會坐等一個永遠不會修好它的版本。

上面清單裡的訊息是**格式示意**。確切文字由 `ValidationMessageTests` 的 golden 表鎖定——沒有那張表時，`XS1101` 曾一度輸出 `requires swiftui`（rawValue）而非規格寫的 `requires SwiftUI`，且無人察覺。

---

## 7. 模板系統

### 7.1 三類產出物，三種機制

原始計劃書把所有產出物都當成「模板層」處理，因此需要 `merge-yaml` / `merge-json` 之類的衝突合併策略。實際上產出物有三類，各自該用不同機制：

| 類別 | 例子 | 機制 |
|---|---|---|
| 結構化資料 | `project.yml` | Swift 型別建構後序列化（[ADR-0002](../adr/0002-build-project-yml-from-swift-types.md)） |
| 原始碼 | `AppDelegate.swift`、`ContentView.swift` | 靜態模板檔 + 變數代換 |
| 工具設定檔 | `.swiftlint.yml`、`Makefile`、`.gitignore` | 靜態檔 + 變數代換 |

因此 v0.1 **沒有** `merge-yaml`、`merge-json`、`append`、`replace-generated` 這些策略。檔案衝突只有兩種處置：`create-only`（預設）與 `error`。

### 7.2 三層

```text
Templates
├── Shared              所有 Variant 共用
│   ├── .gitignore
│   ├── .swiftlint.yml
│   ├── .swiftformat
│   ├── Makefile
│   └── README.md
├── Variants            platform × language × interface，彼此不共用原始碼
│   ├── ios-uikit
│   └── ios-swiftui
└── Architectures       疊加層
    └── minimal
```

`platform × language × interface` 是**互斥**維度——iOS UIKit 的 `AppDelegate.swift` 跟 SwiftUI 的 `App.swift` 沒有一行共用，適合整包目錄。`architecture` 是**疊加**維度，適合 overlay。

### 7.3 Architecture overlay 在 v0.1 只產文件

v0.1 的 architecture overlay **不生成資料夾，也不生成基底型別**，只在生成專案的 `README.md` 裡寫出架構說明與檔案結構圖。

理由：空資料夾在 git 裡不存在（要塞 `.gitkeep`）；生成一堆使用者不會用的基底 protocol 是最典型的 scaffold 垃圾，開專案第一件事就是刪掉它們；而對 AI agent 來說，文字架構說明比空資料夾有用得多。

這也讓 overlay 的介面型別在 v0.1 維持簡單。等 v0.2 真的做 MVVM 或 Clean 時，才需要決定 overlay 要不要升級成「XcodeGen spec 變換器 + 檔案」——那時會有實際案例可以判斷。

### 7.4 生成專案的文件

生成的專案只含 `README.md`，內容包含用途、環境需求、安裝、開發／測試／建置指令、架構摘要與檔案結構圖。

**不生成 `AGENTS.md` 或 `CLAUDE.md`**，由開發者自行 `/init`。

---

## 8. UIKit variant 的設計

**純程式碼建 UI，零 storyboard 檔案。**

- `LaunchScreen.storyboard` 以 Info.plist 的 `UILaunchScreen` 字典取代（iOS 14+，本專案 deployment target 為 18.0）
- 沒有 `Main.storyboard`

理由：選 XcodeGen 的核心動機是避開 `.pbxproj` 的 merge conflict，而 `Main.storyboard` 有一模一樣的問題——同樣是機器產生的 XML，同樣會在多人同時改動時炸開。前門擋了後門開沒有意義。此外 storyboard segue 與 Coordinator 模式互斥，用 storyboard 等於提前堵死 v0.2 的 MVVM-C。

Xcode 26.4 的內建 UIKit 樣板仍使用 `AppDelegate` + `SceneDelegate`，本專案沿用。

---

## 9. 環境與 scheme

一個 Environment 對應**一個 scheme**。

| Environment | Build Configuration | Scheme | Bundle ID 後綴 | 顯示名稱後綴 |
|---|---|---|---|---|
| `development` | `Debug` | `MyApp-Development` | `.dev` | ` Dev` |
| `staging` | `Staging` | `MyApp-Staging` | `.stg` | ` STG` |
| `production` | `Release` | `MyApp` | 無 | 無 |

`environments: []` 時只產生 `Debug` / `Release` 兩個 configuration 與一個 scheme。

### 9.1 兩條生成規則

`Environment` 少了兩項 XcodeGen 需要的資訊。兩者都以**生成規則**補足，不加 schema 欄位——需要例外的人直接改 `project.yml`，那是生成後的真實來源（[ADR-0001](../adr/0001-scaffold-yml-as-birth-certificate.md)）。

1. **哪些 configuration 是 debug 建置**：名為 `Debug` 的是，其餘為 release。XcodeGen 的 `configs:` 必須標記，而 schema 沒有記錄。
   **退化情況**：若沒有任何環境使用 `Debug` 這個名稱，則**第一個環境**成為 debug 建置。全部標成 release 會產生一個根本無法除錯的專案，那比猜一個更糟；而環境清單慣例上由開發環境往外排。
2. **哪個 scheme 用無後綴的原名**：`configuration` 為 `Release` 的那個。它是 archive 上架用的 scheme，也是打開專案時預設選中的。若沒有任何環境使用 `Release`，則全部加後綴。

Scheme 後綴用環境名稱首字大寫（`development` → `Development`），**不縮寫成 `Dev`**：那需要一張任意的對照表，且對沒見過的名稱沒有正確答案。

### 9.2 顯示名稱的實作

每個環境的顯示名稱透過 build setting 而非多份 Info.plist：`Info.plist` 寫 `CFBundleDisplayName: $(PRODUCT_DISPLAY_NAME)`，各 configuration 定義自己的 `PRODUCT_DISPLAY_NAME`。一份 Info.plist 服務所有環境。

已實測驗證：建置 Staging configuration 後，產物 `Info.plist` 的 `CFBundleDisplayName` 確實是 `EnvProbe STG`，`CFBundleIdentifier` 是 `com.example.envprobe.stg`。

因此生成樹裡**沒有** `Config/`（`.xcconfig`）——per-configuration 設定直接寫在 `project.yml` 裡。§13.1 已同步。

---

## 10. 生成流程

```text
載入設定 → 套用預設值 → 驗證 → 解析模板 → 建立 GenerationPlan → 檢查衝突
    ↓
建立暫存工作區 → 渲染檔案 → 原子搬移到目的地
    ↓
git init → initial commit → xcodegen generate
```

規則：

- 所有寫入必須先經過 `GenerationPlan`
- 不在目的目錄邊生成邊修改；先在暫存區完成，再原子搬移
- 失敗時 rollback，目的目錄不得留下半成品
- 所有外部指令必須經過 `ProcessRunner`，以便測試替換

### 10.1 `init` 預設跑到哪裡

**預設會執行 `xcodegen generate`。** 缺少 xcodegen 時以 exit code 10 明確失敗，**不靜默跳過**——那會讓同一份 `scaffold.yml` 在兩台機器產生不同結果，直接牴觸可重現性主張。

**預設不跑 formatter。** 模板是靜態檔案，變數只出現在字串與識別字位置。模板本身的格式正確性由 xscaffold 自己的 CI lint 模板檔案來保證，一次到位，生成時不需要使用者安裝 SwiftFormat。

**預設不跑 `xcodebuild`。** build 驗證的真正需求者是模板測試套件，不是每個開專案的使用者。它移到 CI（§12），使用者端以 `--validate-build` opt-in。

`.xcodeproj` 是衍生物，進 `.gitignore`。生成的 README 第一段說明 clone 後先跑 `make generate`。

---

## 11. CLI 契約

### 11.1 指令

```bash
xscaffold init [name]      建立專案
xscaffold validate <path>  驗證設定
xscaffold plan             預覽 GenerationPlan（與 init --dry-run 共用實作）
xscaffold doctor           檢查 xcodegen / Xcode 是否可用
```

`plan` 與 `init --dry-run` 是同一份實作的兩個入口，輸出同一個 `GenerationPlan`。

### 11.2 Flag

```text
--config <path>
--preset <name>
--destination <path>
--output <text|json>
--dry-run
--force
--skip-git
--skip-generate
--validate-build
--yes
```

執行行為一律走 flag，不進 `scaffold.yml`。

### 11.3 JSON output

```text
--output json 時：
  stdout 只輸出 JSON
  stderr 輸出 log
  不輸出 ANSI 顏色
  禁止互動
  失敗時仍輸出合法 JSON
```

### 11.4 Exit code

```text
0    Success
1    Unexpected failure
2    Invalid CLI arguments
3    Configuration parsing failure
4    Configuration validation failure
5    Template resolution failure
6    File conflict
7    Generation failure
8    External command failure
9    Build validation failure
10   Environment requirement missing
130  User cancelled
```

---

## 12. 測試策略

### 12.1 三層

**Unit**（Swift Testing）
Schema round-trip（YAML → model → YAML 語意一致）、預設值解析、驗證規則正反案例、XcodeGen spec 建構（比對結構而非字串）。

**契約 snapshot**
只鎖三樣東西：生成的檔案清單、`project.yml`、JSON output 的欄位。

`project.yml` **兩種都鎖**，而且是唯一逐字比對的檔案：

- **解析後結構** —— 失敗時代表「生成的專案會不一樣」，是有意義的訊號。
- **逐字文本** —— 因為它的鍵順序與引號是有意義的：順序決定 diff 是否穩定，引號決定 `18.10` 會不會被 YAML 讀成浮點數 `18.1`（另一個 iOS 版本）。結構比對抓不到這兩者。

它是下面那條「不逐字比對」規則的**唯一例外**，理由是它只有一個檔案、完全由工具生成、沒有註解，而且它正是使用者往後每天 diff 的東西。

檔案**內容**不逐字比對——那是 snapshot 最常見的失敗模式：粒度太細，改一個註解就要更新一堆 snapshot，接著養成無腦 accept 的習慣，snapshot 就失去全部價值。內容正確性交給 E2E build 把關。

額外加一條斷言：**任何產出物中不得殘留未代換的變數標記**。這擋掉「變數沒代換到卻仍能編譯」這個唯一的漏網情境。

**E2E**（CI，每次 push）
兩個 variant 各跑一次 `xcodegen generate` → `xcodebuild build` → `xcodebuild test`。

公開 repository 使用標準 GitHub-hosted runner（含 macOS）**免費且不計量**，所以沒有理由省這一步。

### 12.2 已實測驗證的事實

以下在 Xcode 26.4.1 / Swift 6.3.1 / iOS SDK 26.4 上實際跑過：

**Swift Testing 在 XcodeGen 產生的 `.xcodeproj` 中可正常運作。** `@Test`、`#expect`、參數化 `@Test(arguments:)`、`@testable import` 全部正常，在 `SWIFT_VERSION = 6` 與 `SWIFT_STRICT_CONCURRENCY = complete` 下通過。

**兩個模板必須處理的坑：**

1. XcodeGen 產生的 unit test target 預設沒有 Info.plist，會以 `Cannot code sign because the target does not have an Info.plist file` 直接失敗。測試 target 必須設定 `GENERATE_INFOPLIST_FILE: YES`。
2. `-destination 'platform=iOS Simulator,name=iPhone 16'` 有歧義——同名裝置在多個 iOS runtime 各有一台，xcodebuild 會警告並任選第一個。生成的 `Makefile` 與 CI workflow **必須指定明確的 OS 版本或 udid**，否則測試跑在哪台機器是不確定的，這會直接牴觸可重現性主張。

---

## 13. 執行順序

| Milestone | 內容 | 驗收 |
|---|---|---|
| M1 | `Package.swift` 三個 target、CI、coding conventions | `swift build` / `swift test` |
| M2 | Schema 型別、預設值、YAML 編解碼 | YAML → model → YAML 語意一致 |
| M3 | 驗證函式、`ValidationIssue`、錯誤碼 | 每條規則正反案例；`XS0xxx` 與 `XS1xxx` 語氣正確 |
| M4 | XcodeGen spec 建構與序列化 | 結構比對；`environments` 開／關兩種輸出 ✅ |
| M5 | 模板載入、變數代換、`GenerationPlan` | 契約 snapshot |
| M6 | `init` 落地：暫存區 → 原子搬移 → git → xcodegen | 兩個 variant 都能 `open` |
| M7 | `validate` / `plan` / `doctor`、JSON output、exit code | JSON 契約 snapshot |
| M8 | CI E2E | 兩個 variant 的 `xcodegen` → `build` → `test` 全綠 |
| M9 | `SKILL.md`、schema reference、`make install`、README | 用 Claude Code 走完一次自然語言 → 專案 |

### 13.1 v0.1 Definition of Done

```bash
xscaffold init DemoApp --preset ios-uikit --destination /tmp/DemoApp
```

產生：

```text
DemoApp
├── App/                    AppDelegate、SceneDelegate、ViewController
├── Resources/              必須有內容；空目錄在 git 裡不存在，xcodegen 會失敗
├── Tests/
├── project.yml
├── scaffold.yml
├── .swiftlint.yml
├── .swiftformat
├── Makefile
├── .gitignore
└── README.md
```

**沒有 `Config/`。** 早期版本的計劃書在啟用 environments 時會產生一組 `.xcconfig`。M4 之後不需要了：per-configuration 的 bundle identifier 與顯示名稱直接寫在 `project.yml` 的 `settings.configs` 裡（§9.2）。少一層檔案、少一個會與 `project.yml` 不同步的地方。

**沒有 `App/Info.plist` 模板。** 那個檔案由 XcodeGen 依 `project.yml` 的 `info.properties` 產生，因此它是衍生物，不是模板產出物。同一個理由：描述只有一份。

並通過：

```bash
xcodegen generate
xcodebuild build -scheme DemoApp -destination '<明確 udid>'
xcodebuild test  -scheme DemoApp -destination '<明確 udid>'
swiftlint
swiftformat --lint .
```

`ios-swiftui` preset 同樣通過。

---

## 14. 明確排除的範圍

以下項目已從計劃移除，不在任何已規劃版本中。若要恢復，需先重新檢視 [ADR-0001](../adr/0001-scaffold-yml-as-birth-certificate.md)。

**因為 ADR-0001（出生證明模型）而移除**
`.xscaffold` ownership manifest、檔案 checksum、template-lock、`xscaffold generate` 重新生成、模板升級、設定遷移、`inspect`、`import`、`add feature` / `add package` / `add target` / `add integration`、Integration Registry。

**因為 ADR-0002（Swift 型別建構）而移除**
`merge-yaml`、`merge-json`、`append`、`replace-generated`、七種衝突策略與優先序、樣板引擎。

**因為範圍收斂而移除**
Objective-C 與 Mixed 全線、CocoaPods、clang-format、Strict Clang Warnings、Periphery、Fastlane、生成 GitHub Actions workflow、`CompatibilityRule` protocol 與 Resolver、`AvailableProjectOptions`、`config` 指令、`template` 指令、Package Registry 與 Feature Provider（延後至 v0.3 之後再評估）。

**延後**
互動式 prompt（v0.2）、macOS variant（v0.2）、MVVM 與 MVVM-C overlay（v0.2）、Tuist（未定）、Homebrew tap（1.0 之後）。

---

## 15. v0.2 候選

- macOS SwiftUI variant
- macOS AppKit variant
- Architecture overlay 升級：MVVM、MVVM-C。**此時才決定** overlay 要不要從「純檔案疊加」升級成「XcodeGen spec 變換器 + 檔案」，因為那時會有實際案例
- 互動式 prompt。Prompt 只負責收集輸入並填出 `PartialProjectConfiguration`，不得內嵌任何相容性規則

---

## 16. Skill Adapter

Skill 與 v0.1 **同步交付**，而不是排在最後。

原因：寫 `SKILL.md` 是檢驗 CLI 契約好不好用最便宜的方式。如果要寫三頁才能解釋清楚怎麼呼叫 `xscaffold`，那是 CLI 設計有問題的訊號，而你會在第一週就發現。

### 16.1 內容

```text
Skills/xcode-project-scaffold
├── SKILL.md
└── references
    └── configuration-schema.md
```

**不包含 shell script 包裝層。** Agent 直接執行 `xscaffold validate --output json` 即可。包一層 shell 只是多一個失敗點、多一份要維護的東西，而且會遮蔽 CLI 的原始錯誤訊息與 exit code——那正是 agent 最需要看到的資訊。

**不包含 `agents/openai.yaml`**，除非確定要跨工具。

### 16.2 工作流程

```text
理解需求 → 產生 scaffold.yml
    → xscaffold validate --output json
    → 修正可自動修正項目
    → xscaffold plan --output json
    → 顯示摘要
    → xscaffold init --output json
    → 回報結果
```

Skill 不得自行判斷相容性、不得自行產生 `.xcodeproj`、不得在未驗證的設定下生成專案。

---

## 17. 安裝

0.x 階段：

```bash
git clone <repo>
make install     # swift build -c release → ~/.local/bin
```

目標使用者全是 iOS 開發者，機器上必定有 Swift toolchain，所以 source install 的門檻極低，而且零基礎建設。

不做預編 binary 發佈：從網路下載的執行檔會被 Gatekeeper 隔離，需要 Developer ID 簽章與公證才能順利執行，這對 0.x 是不成比例的成本。自行 `swift build` 出來的執行檔沒有這個問題。

Homebrew tap 留到 1.0 之後。

---

## 18. Code Agent 工作規範

### 18.1 每個 Issue 的輸出

變更摘要、設計決策、修改檔案、新增測試、執行指令、測試結果、未完成事項、風險與後續建議。

### 18.2 實作原則

- 不在 CLI 中重複 `ScaffoldCore` 的規則
- `ScaffoldSchema` 不得引入檔案系統或子行程相依
- 不直接編輯 `.pbxproj`
- 所有寫入必須經過 `GenerationPlan`
- 所有外部命令必須經過 `ProcessRunner`
- 所有新增 schema 欄位必須同步更新：預設值、YAML 編解碼、驗證、JSON output、`Skills/.../references/configuration-schema.md`、測試
- 所有新增驗證規則必須有正反案例
- 所有新增 variant 必須有契約 snapshot 與 E2E build 驗證
- 新增用語前先讀 `CONTEXT.md`；若該用語尚未定義，先在 `CONTEXT.md` 定義再使用

### 18.3 Commit 慣例

```text
feat(schema): add project configuration model
feat(validation): add interface and lifecycle rules
feat(cli): add validate command
feat(template): add ios-uikit variant
test(integration): add xcodebuild validation for both variants
docs(adr): record birth certificate decision
```

---

## 19. 最終決策摘要

```text
Repository      xcode-project-scaffold（public，0.x 無相容性承諾）
Executable      xscaffold
定位            只做 init，不管理既有專案
核心契約        scaffold.yml（出生證明）
Generator       XcodeGen（子行程呼叫，不吃函式庫相依）
v0.1 範圍       iOS + Swift + UIKit / SwiftUI + Minimal
預設基準        iOS 18.0 + Swift 語言模式 6 + strict concurrency
模組            ScaffoldSchema / ScaffoldCore / xscaffold
模板            Shared / Variants / Architectures
指令            init / validate / plan / doctor
安裝            make install
```

第一個實作目標是一條可編譯、可測試、可重現的垂直切片，並且**在完成當天就能用於實際專案**。
