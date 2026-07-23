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

**Preset**:
一組具名的 `ProjectConfiguration` 預設值。它是預設值集合，不是模板。
_Avoid_: profile、template、範本

## 生成

**GenerationPlan**:
生成前算出的完整計畫——要建立哪些檔案、要執行哪些外部指令。`plan` 與 `init --dry-run` 輸出的就是它。
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

**Placeholder**:
模板裡的 `{{NAME}}`。渲染時必須有對應的值，否則是錯誤。
_Avoid_: variable、token、變數、生成清單

**Generator**:
把 `project.yml` 轉成 `.xcodeproj` 的外部工具。目前只有 XcodeGen。
_Avoid_: backend、engine

**XcodeGenSpec**:
`ProjectConfiguration` 與 `project.yml` 之間的中介值。它描述要寫出什麼，不描述怎麼寫。所有決定都在這一層，序列化器不自行發明任何值。
_Avoid_: project spec、YAML model

**ValidationIssue**:
驗證階段產出的單一問題，含嚴重度、錯誤碼、訊息、路徑與建議。錯誤碼 `XS0xxx` 表示這個版本還沒支援，`XS1xxx` 表示這個組合永遠不合法。
_Avoid_: error、warning、diagnostic

## 模板

**Variant**:
platform × language × interface 的一個具體組合，例如 `ios-uikit`。各 Variant 之間不共用原始碼。
_Avoid_: template、flavor、combination、組合

**Shared Layer**:
所有 Variant 共用的檔案，例如 `.swiftlint.yml`、`Makefile`、`.gitignore`。
_Avoid_: base、common、共用層

**Architecture Overlay**:
疊加在 Variant 之上、描述架構慣例的一層。
_Avoid_: pattern layer、architecture template

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
