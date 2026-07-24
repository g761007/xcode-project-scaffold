# Xcode Project Scaffold

用一份可版控的設定，可重現地建立新的 Xcode 專案。

這份文件是專案的統一用語表。它只定義詞彙，不記錄實作決策——那些屬於 `docs/adr/`。

## 設定與契約

**scaffold.yml**:
描述一個 Xcode 專案應該長成什麼樣子的宣告式設定檔。
_Avoid_: config、manifest、專案設定檔

**出生證明**:
`scaffold.yml` 在專案生成之後的角色——記錄這個專案由哪份設定產生，不再是後續變更的真實來源。
_Avoid_: source of truth、manifest

**ProjectConfiguration**:
`scaffold.yml` 解析並填入預設值後的完整 Swift 值。生成流程的唯一輸入。
_Avoid_: config object、settings、options

**PartialProjectConfiguration**:
`new` 互動收集到的高訊號欄位，在套用預設值與驗證之前的樣子。它只帶 prompt 問到的欄位，`resolved()` 交給 `ProjectConfiguration` 補齊其餘。它讓 prompt 能在不懂任何相容性規則的情況下收集輸入——產出一份這個值，由驗證層而非 prompt 決定能不能生成。
_Avoid_: answers、draft config、partial

**ValidatedConfiguration**:
通過驗證的 `ProjectConfiguration` 的證明包裝。只有 `ConfigurationValidator` 能建構它，而生成入口只接受它——一份沒過驗證的設定，在編譯期就到不了生成。它是證明，不是第二種設定型別。
_Avoid_: checked config、safe config

**Preset**:
專案規模與預設功能的具名集合（minimal / standard / production），v0.7 生效，屆時以
`--preset` 提供。在那之前這個詞不指任何現役概念——v0.4 之前掛在 `--preset` 下的四個
平台組合現在叫 Variant（ADR-0007）。
_Avoid_: profile、template、範本、（舊語意）平台組合

## 生成

**GenerationPlan**:
生成前算出的完整計畫——要建立哪些檔案、要執行哪些外部指令。`plan` 輸出的就是它，`generate` 執行的也是它。
_Avoid_: diff、changeset

**PlannedFile**:
`GenerationPlan` 裡的一個檔案：目的地相對路徑與已渲染完成的內容。
_Avoid_: output file、artifact

**PlannedCommand**:
`GenerationPlan` 裡的一個外部指令，附帶一句說明它為何存在。
_Avoid_: step、task

**GenerationOptions**:
一次執行的選項（要不要初始化 git、要不要呼叫 generator）。它描述的是**這次執行**而非專案，所以只來自 CLI flag，永遠不會出現在 `scaffold.yml` 裡。

它決定的是**計畫裡有什麼**。決定「計畫怎麼落地」的選項——例如 `--force`——不屬於它，那是 `PlanExecutor` 的參數：兩份 `GenerationPlan` 不會因為加不加 `--force` 而不同。
_Avoid_: settings、config

**PlanExecutor**:
把 `GenerationPlan` 落到磁碟的執行者：先寫進暫存區，再搬到目的地，最後執行 `PlannedCommand`。它只執行計畫，不做任何決定。
_Avoid_: writer、generator、生成器

**暫存區**:
生成過程中先寫入的臨時目錄，位置是目的地的兄弟目錄。所有檔案在這裡完成後才一次移入目的地，因此目的地不會出現半成品。
_Avoid_: 暫存檔、temp 目錄、工作區

**ProcessRunner**:
執行外部指令的唯一介面，輸入是 `ProcessInvocation`（指令、參數、工作目錄），輸出是 `ProcessResult`（結束狀態與兩個輸出串流）。所有子行程都必須經過它，測試才能在不真的執行任何指令的情況下檢查一次執行會做什麼。
_Avoid_: shell、executor、command runner

**Prompter**:
互動輸入的唯一介面：顯示一行問題、讀一行答案、以及這是不是可作答的終端機。`new` 的所有互動都必須經過它，測試才能用腳本化答案驅動整個收集流程而不需真的終端機。與 `ProcessRunner` 是同一種東西，方向相反。
_Avoid_: input reader、console、readLine

**Placeholder**:
模板裡的 `{{NAME}}`。渲染時必須有對應的值，否則是錯誤。
_Avoid_: variable、token、變數、生成清單

**Generator**:
把 `project.yml` 轉成 `.xcodeproj` 的外部工具。目前只有 XcodeGen。
_Avoid_: backend、engine

**XcodeGenSpec**:
`ProjectConfiguration` 與 `project.yml` 之間的中介值。它描述要寫出什麼，不描述怎麼寫。所有決定都在這一層，序列化器不自行發明任何值。
_Avoid_: project spec、YAML model

**ProjectContainer**:
生成專案被驅動的容器：`.xcodeproj` 本體，或（CocoaPods／mixed 時）`pod install` 產生的
`.xcworkspace`。Build、Test、Open 一律由它決定 `-project` 或 `-workspace`，規則只寫一次，
呼叫端不得各自判斷 dependency manager。
_Avoid_: workspace flag、project kind

**CommandOutput**:
`--output json` 時每個指令寫到 stdout 的那份文件，成功與失敗共用一種信封。`ok`、`command` 與 `exitCode` 永遠都在，`message` 在失敗時出現，其餘欄位（`issues`、`plan`、`checks`、`destination`）有話說才出現。
_Avoid_: response、payload、回傳值

**PlanSummary**:
`GenerationPlan` 在 `CommandOutput` 裡的樣子：檔案路徑與位元組數，加上要執行的指令。**不含檔案內容**——呼叫端拿它做的事沒有一項需要內容。
_Avoid_: plan output、摘要

**ScaffoldExitCode**:
CLI 的結束碼（§11.4）。它是契約的一部分而非實作細節：呼叫端靠它分辨「你的設定有問題」與「這台機器沒裝 XcodeGen」。
_Avoid_: error code、status

**EnvironmentCheck**:
`doctor` 對某個外部工具的一次檢查結果：有沒有裝、是不是必要、以及版本。它描述的是**這台機器**，不是設定。
_Avoid_: dependency、requirement、環境變數

**ValidationIssue**:
驗證階段產出的單一問題，含嚴重度、錯誤碼、訊息、路徑與建議。錯誤碼 `XS0xxx` 表示這個版本還沒支援，`XS1xxx` 表示這個組合永遠不合法。
_Avoid_: error、warning、diagnostic

## 模板

**Variant**:
platform × language × interface 的一個具體組合，例如 `ios-uikit`。各 Variant 之間不共用原始碼。
CLI 以 `--variant` 選取（`new MyApp --variant ios-uikit`）；`scaffold.yml` 內仍是 platform 與
interface 兩個欄位，variant 只是一次答兩題的捷徑。
_Avoid_: template、flavor、combination、組合、preset（v0.4 起）

**Shared Layer**:
所有 Variant 共用的檔案，例如 `.swiftlint.yml`、`Makefile`、`.gitignore`，以及**平台中性**的資產（如 `AccentColor`）。平台專屬的資產不在這裡——`AppIcon` 因 iOS 與 macOS 的圖示不同而下放到各 Variant。
_Avoid_: base、common、共用層

**Architecture Overlay**:
疊加在 Variant 之上、描述架構慣例的一層。它一定貢獻一段架構說明與 Mermaid 圖給生成專案的 README；當該 pattern 有範例且專案沒關掉時，還貢獻**範例**原始碼，以同路徑取代 Variant 的預設主畫面。
_Avoid_: pattern layer、architecture template

**範例（Example）**:
Architecture Overlay 為 `mvvm`／`mvvm-c` 生成的一段可運作程式碼——取代 App 主畫面的 View 與具體 ViewModel（MVVM-C 再加 Coordinator 與兩畫面流程）。它是可以直接刪或擴充的實作，不是抽象基底層。由 `architecture.includeExample` 控制生不生。
_Avoid_: sample、boilerplate、樣板

**Coordinator**:
MVVM-C 範例裡掌管導航的物件：View 回報意圖（選取），由 Coordinator 而非 View 決定下一個畫面並推入。導航因此離開了 View 與 ViewModel。
_Avoid_: router、navigator（作為 MVVM-C 語境的同義詞時）

## 專案內容

**Provider**:
某項技術選型的實作者，例如 networking 的 `urlsession` 或 `alamofire`。
_Avoid_: library、feature、capability

**Feature**:
使用者 App 裡的一個功能模組，例如 Profile。與 feature-first 的用法一致。
_Avoid_: module、capability、功能

**Capability**:
Xcode 原生能力，例如 Push Notifications、App Groups，底層對應 entitlement。不用來指技術選型。
_Avoid_: feature、entitlement（作為使用者可見詞彙時）

**Environment**:
專案的一組建置變體，例如 development / staging / production。每個 Environment 對應一個 build configuration、一個 scheme，以及可選的 bundle identifier 與顯示名稱後綴。
_Avoid_: scheme、configuration、flavor、環境變數
