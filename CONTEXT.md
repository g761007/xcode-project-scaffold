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
_Avoid_: diff、changeset、生成清單

**Generator**:
把 `project.yml` 轉成 `.xcodeproj` 的外部工具。目前只有 XcodeGen。
_Avoid_: builder、backend、engine

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
