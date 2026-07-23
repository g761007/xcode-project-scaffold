# xcode-project-scaffold 完整開發計劃

> 目標讀者：專案擁有者、Code Agent  
> Repository：`xcode-project-scaffold`  
> CLI：`xscaffold`  
> 核心模式：CLI Core + Skill Adapter  
> 核心契約：`scaffold.yml`

---

## 1. 專案目標

建立一套以 Swift 開發的 Xcode 專案初始化、分析、標準化與後續維護工具。

工具需同時支援：

- iOS 與 macOS。
- Swift、Objective-C，以及後續的 Swift／Objective-C Mixed 專案。
- SwiftUI、UIKit、AppKit。
- 互動式 CLI。
- 宣告式 `scaffold.yml`。
- AI Skill Adapter。
- 新專案建立。
- 既有專案分析與設定反向推導。
- 第三方套件與整合能力管理。
- 專案生成、驗證、重新產生與遷移。

主要指令：

```bash
xscaffold init
```

完整使用模式：

```text
Interactive CLI
    ↓
xscaffold init

Declarative Configuration
    ↓
xscaffold init --config scaffold.yml

AI Skill Adapter
    ↓
Natural Language
    ↓
scaffold.yml
    ↓
xscaffold validate
    ↓
xscaffold plan
    ↓
xscaffold init
```

---

## 2. 核心產品定位

`xcode-project-scaffold` 不只是建立資料夾與 Xcode Project，而是：

> 一套支援 Xcode 專案初始化、配置描述、標準化、分析與生命週期管理的工具。

核心價值：

1. 將建立專案的選項轉成可版本控制的設定。
2. 保證相同設定可重現相同專案結構。
3. 統一平台、語言、架構、套件與工具鏈選項。
4. 讓 CLI、CI、Code Agent 與 Skill 共用同一套 Core。
5. 支援既有專案匯入與標準化。
6. 避免 AI Agent 自行拼裝 `.pbxproj` 或產生不一致結構。

---

## 3. 專案名稱與命令

```text
Repository
xcode-project-scaffold

Executable
xscaffold
```

主要命令：

```bash
xscaffold init
xscaffold validate
xscaffold plan
xscaffold doctor
xscaffold inspect
xscaffold import
xscaffold add
xscaffold generate
xscaffold config
xscaffold template
```

---

## 4. 設計原則

### 4.1 Core 是唯一真實來源

以下能力必須由 Core 提供：

- Schema parsing。
- Default value resolution。
- Compatibility resolution。
- Validation。
- Template selection。
- Dependency resolution。
- Generation planning。
- File conflict policy。
- Generation transaction。
- Machine-readable output。

CLI、Skill 與其他 Agent 只能呼叫 Core，不可重複實作規則。

### 4.2 `scaffold.yml` 是核心契約

所有互動選項最後都必須轉換為：

```text
ProjectConfiguration
```

並可匯出：

```text
scaffold.yml
```

反向也必須能從 `scaffold.yml` 產生專案。

```text
相同 xscaffold 版本
+ 相同模板版本
+ 相同 scaffold.yml
= 相同專案結構
```

### 4.3 不直接編輯 `.pbxproj`

MVP 使用：

```text
XcodeGen
```

後續加入：

```text
Tuist
```

既有專案分析可以讀取 `.xcodeproj`，但新專案生成不自行操作 `.pbxproj`。

### 4.4 Prompt 不包含業務規則

Interactive Prompt 只負責收集輸入。

相容性與選項過濾由：

```text
CompatibilityResolver
```

統一處理。

### 4.5 Skill 是 Adapter，不是 Generator

Skill 負責：

- 理解自然語言需求。
- 補齊必要資訊。
- 推薦 Preset。
- 產生 `scaffold.yml`。
- 呼叫 CLI。
- 解讀 JSON 結果。

Skill 不負責：

- 自行產生 `.xcodeproj`。
- 自行產生模板內容。
- 自行判斷 Compatibility Matrix。
- 直接修改 `.pbxproj`。
- 在未驗證設定下生成專案。

---

## 5. 支援範圍

### 5.1 MVP 支援矩陣

| Platform | Language | UI | Lifecycle | MVP |
|---|---|---|---|---|
| iOS | Swift | SwiftUI | SwiftUI App | ✅ |
| iOS | Swift | UIKit | AppDelegate + SceneDelegate | ✅ |
| iOS | Objective-C | UIKit | AppDelegate + SceneDelegate | ✅ |
| macOS | Swift | SwiftUI | SwiftUI App | ✅ |
| macOS | Swift | AppKit | AppDelegate | ✅ |
| iOS | Mixed | UIKit + SwiftUI | AppDelegate + SceneDelegate | v0.2 |
| macOS | Objective-C | AppKit | AppDelegate | v0.2 |
| macOS | Mixed | AppKit + SwiftUI | AppDelegate | v0.2 |

### 5.2 MVP Product Type

第一版只支援：

```text
application
```

後續支援：

- Framework。
- Static Library。
- Dynamic Library。
- Command Line Tool。
- Swift Package。
- Widget Extension。
- Share Extension。
- Notification Service Extension。

### 5.3 平台預留

Schema 可預留：

- watchOS。
- tvOS。
- visionOS。

但未完成模板前，不顯示在 CLI 選項中。

---

## 6. Repository 結構

```text
xcode-project-scaffold
├── Package.swift
├── README.md
├── LICENSE
├── Makefile
├── CHANGELOG.md
│
├── Sources
│   ├── XScaffoldCLI
│   │   ├── XScaffold.swift
│   │   └── Commands
│   │       ├── InitCommand.swift
│   │       ├── ValidateCommand.swift
│   │       ├── PlanCommand.swift
│   │       ├── DoctorCommand.swift
│   │       ├── InspectCommand.swift
│   │       ├── ImportCommand.swift
│   │       ├── AddCommand.swift
│   │       ├── GenerateCommand.swift
│   │       ├── ConfigCommand.swift
│   │       └── TemplateCommand.swift
│   │
│   ├── ScaffoldSchema
│   │   ├── ProjectConfiguration.swift
│   │   ├── PartialProjectConfiguration.swift
│   │   ├── Platform.swift
│   │   ├── ProductType.swift
│   │   ├── ProgrammingLanguage.swift
│   │   ├── UIFramework.swift
│   │   ├── ApplicationLifecycle.swift
│   │   ├── ArchitecturePattern.swift
│   │   ├── ProjectCapability.swift
│   │   └── ConfigurationDefaults.swift
│   │
│   ├── ScaffoldCore
│   │   ├── Compatibility
│   │   ├── Validation
│   │   ├── Planning
│   │   ├── DependencyResolution
│   │   ├── Generation
│   │   └── Errors
│   │
│   ├── ScaffoldPrompt
│   │   ├── PromptEngine.swift
│   │   ├── TextPrompt.swift
│   │   ├── SelectPrompt.swift
│   │   ├── MultiSelectPrompt.swift
│   │   ├── ConfirmPrompt.swift
│   │   └── TerminalRenderer.swift
│   │
│   ├── ScaffoldTemplates
│   │   ├── TemplateLoader.swift
│   │   ├── TemplateManifest.swift
│   │   ├── TemplateResolver.swift
│   │   ├── TemplateRenderer.swift
│   │   └── TemplateValidator.swift
│   │
│   ├── ScaffoldGenerators
│   │   ├── ProjectGenerating.swift
│   │   ├── XcodeGenGenerator.swift
│   │   └── TuistGenerator.swift
│   │
│   ├── ScaffoldDependencies
│   │   ├── PackageRegistry.swift
│   │   ├── PackageDescriptor.swift
│   │   ├── IntegrationDescriptor.swift
│   │   └── FeatureProviderResolver.swift
│   │
│   ├── ScaffoldInspector
│   │   ├── ProjectInspector.swift
│   │   ├── XcodeProjectInspector.swift
│   │   ├── SourceInspector.swift
│   │   ├── DependencyInspector.swift
│   │   ├── ToolingInspector.swift
│   │   ├── ArchitectureInspector.swift
│   │   ├── EnvironmentInspector.swift
│   │   └── ConfigurationImporter.swift
│   │
│   └── ScaffoldSystem
│       ├── FileSystemClient.swift
│       ├── ProcessRunner.swift
│       ├── EnvironmentInspector.swift
│       ├── GitClient.swift
│       └── GenerationTransaction.swift
│
├── Templates
│   ├── Bases
│   ├── Platforms
│   ├── Languages
│   ├── Interfaces
│   ├── Architectures
│   └── Capabilities
│
├── Registry
│   ├── packages.yml
│   ├── integrations.yml
│   └── presets
│       ├── ios-modern.yml
│       ├── ios-legacy.yml
│       ├── ios-migration.yml
│       └── macos-modern.yml
│
├── Skills
│   └── xcode-project-scaffold
│       ├── SKILL.md
│       ├── agents
│       │   └── openai.yaml
│       ├── references
│       └── scripts
│
└── Tests
    ├── ScaffoldSchemaTests
    ├── ScaffoldCoreTests
    ├── ScaffoldPromptTests
    ├── ScaffoldTemplateTests
    ├── ScaffoldGeneratorTests
    ├── ScaffoldDependencyTests
    ├── ScaffoldInspectorTests
    ├── ConfigurationSnapshotTests
    └── IntegrationTests
```

---

## 7. 模組依賴方向

```text
XScaffoldCLI
├── ScaffoldPrompt
├── ScaffoldCore
├── ScaffoldInspector
└── ScaffoldSystem

ScaffoldPrompt
└── ScaffoldSchema

ScaffoldCore
├── ScaffoldSchema
├── ScaffoldTemplates
├── ScaffoldDependencies
├── ScaffoldGenerators
└── ScaffoldSystem

ScaffoldTemplates
├── ScaffoldSchema
└── ScaffoldSystem

ScaffoldDependencies
└── ScaffoldSchema

ScaffoldGenerators
├── ScaffoldSchema
└── ScaffoldSystem

ScaffoldInspector
├── ScaffoldSchema
├── ScaffoldDependencies
└── ScaffoldSystem
```

規則：

- `ScaffoldSchema` 不依賴任何其他內部模組。
- CLI 不直接處理檔案生成。
- Prompt 不直接實作 Compatibility Rule。
- Templates 不直接執行 Git。
- Inspector 不修改來源專案。

---

## 8. `scaffold.yml` Schema

```yaml
schemaVersion: 1

project:
  name: MyApp
  organizationName: My Company
  organizationIdentifier: com.example
  bundleIdentifier: com.example.myapp

product:
  platform: ios
  type: application
  deploymentTarget: "17.0"

language:
  primary: swift
  interoperability: none
  swiftVersion: "6.0"

interface:
  primary: swiftui
  secondary: []
  lifecycle: swiftui

architecture:
  pattern: clean
  moduleStyle: feature-first
  navigation: router
  dependencyInjection: protocol-based

generator:
  type: xcodegen
  outputDirectory: .
  projectFileName: MyApp.xcodeproj

dependencies:
  managers:
    - swift-package-manager

features:
  networking:
    provider: urlsession

  dependencyInjection:
    provider: protocol-based

  persistence:
    provider: native

  imageLoading:
    provider: native

  logging:
    provider: oslog

  packages: []

  customPackages: []

  integrations: []

environments:
  - name: development
    configuration: Debug
    bundleIdentifierSuffix: .dev
    displayNameSuffix: Dev

  - name: staging
    configuration: Staging
    bundleIdentifierSuffix: .staging
    displayNameSuffix: Staging

  - name: production
    configuration: Release

quality:
  swiftlint:
    enabled: true

  swiftformat:
    enabled: true

  periphery:
    enabled: false

  clangFormat:
    enabled: false

  strictCompilerWarnings:
    enabled: true

testing:
  unit:
    enabled: true
    framework: swift-testing

  ui:
    enabled: true
    framework: xctest

  integration:
    enabled: false

  snapshot:
    enabled: false
    library: none

automation:
  ci:
    provider: github-actions

  gitHooks:
    provider: lefthook

  fastlane:
    enabled: true

git:
  initialize: true
  initialCommit: true
  defaultBranch: main

output:
  overwritePolicy: prompt
  runBootstrap: true
  generateProject: true
  validateBuild: true
```

---

## 9. Schema 核心型別

```swift
public enum ApplePlatform: String, Codable, CaseIterable, Sendable {
    case iOS = "ios"
    case macOS = "macos"
}

public enum ProductType: String, Codable, CaseIterable, Sendable {
    case application
    case framework
    case staticLibrary = "static-library"
    case dynamicLibrary = "dynamic-library"
    case commandLineTool = "command-line-tool"
    case swiftPackage = "swift-package"
}

public enum ProgrammingLanguage: String, Codable, CaseIterable, Sendable {
    case swift
    case objectiveC = "objective-c"
    case mixed
}

public enum InteroperabilityMode: String, Codable, Sendable {
    case none
    case objectiveC = "objective-c"
    case swift
    case bidirectional
}

public enum UIFramework: String, Codable, CaseIterable, Sendable {
    case swiftUI = "swiftui"
    case uiKit = "uikit"
    case appKit = "appkit"
    case none
}

public enum ApplicationLifecycle: String, Codable, Sendable {
    case swiftUI = "swiftui"
    case appDelegate = "app-delegate"
    case appDelegateSceneDelegate = "app-delegate-scene-delegate"
}

public enum ArchitecturePattern: String, Codable, CaseIterable, Sendable {
    case minimal
    case mvc
    case mvvm
    case mvvmCoordinator = "mvvm-c"
    case clean
}
```

---

## 10. Compatibility Matrix

### 10.1 UI Framework

```text
iOS
├── SwiftUI
└── UIKit

macOS
├── SwiftUI
└── AppKit
```

無效組合：

```text
iOS + AppKit
macOS + UIKit
Objective-C-only + SwiftUI primary
```

### 10.2 Architecture

#### SwiftUI

- Minimal。
- MVVM。
- Clean Architecture。

#### UIKit Swift

- Minimal。
- MVC。
- MVVM。
- MVVM-C。
- Clean Architecture。

#### UIKit Objective-C

- Minimal。
- MVC。
- MVVM。
- MVVM-C。

#### AppKit Swift

- Minimal。
- MVC。
- MVVM。

### 10.3 Testing

```text
Swift-only
├── Swift Testing
└── XCTest

Objective-C-only
└── XCTest

Mixed
├── XCTest
└── Swift Testing for Swift targets
```

### 10.4 Quality Tools

```text
Swift
├── SwiftLint
├── SwiftFormat
└── Periphery

Objective-C
├── clang-format
└── Strict Clang Warnings

Mixed
├── SwiftLint
├── SwiftFormat
├── Periphery
├── clang-format
└── Strict Compiler Warnings
```

---

## 11. Compatibility Resolver

```swift
public protocol CompatibilityResolving: Sendable {
    func availableOptions(
        for partialConfiguration: PartialProjectConfiguration
    ) -> AvailableProjectOptions

    func validate(
        _ configuration: ProjectConfiguration
    ) -> ValidationResult
}
```

Rule：

```swift
public protocol CompatibilityRule: Sendable {
    var identifier: String { get }

    func evaluate(
        _ configuration: ProjectConfiguration
    ) -> [ValidationIssue]
}
```

Validation Issue：

```swift
public struct ValidationIssue: Codable, Sendable {
    public let severity: ValidationSeverity
    public let code: String
    public let message: String
    public let path: String?
    public let suggestion: String?
}
```

初版錯誤碼：

```text
XS1001 UIKit is only available for iOS projects.
XS1002 AppKit is only available for macOS projects.
XS1101 SwiftUI requires Swift as the primary UI language.
XS1201 Swift Testing cannot be used in an Objective-C-only target.
XS1301 SwiftLint is not applicable to Objective-C-only projects.
XS1302 clang-format is disabled for an Objective-C project.
XS1401 The selected architecture is unavailable.
XS1501 Deployment target is unsupported.
XS1601 No template satisfies the requested capabilities.
XS1701 Requested package does not support the selected platform.
XS1702 Requested integration requires missing configuration.
```

---

## 12. Interactive CLI

```text
┌  Xcode Project Scaffold
│
◇  Project name
│  MyApp
│
◇  Platform
│  ● iOS
│  ○ macOS
│
◇  Programming language
│  ● Swift
│  ○ Objective-C
│  ○ Swift + Objective-C
│
◇  User interface
│  ● SwiftUI
│  ○ UIKit
│
◇  Architecture
│  ● Clean Architecture
│  ○ MVVM
│  ○ MVVM-C
│  ○ Minimal
│
◇  Project generator
│  ● XcodeGen
│  ○ Tuist
│
◇  Minimum deployment target
│  ● iOS 17.0
│  ○ iOS 16.0
│  ○ iOS 15.0
│
◇  Networking
│  ● URLSession
│  ○ Alamofire
│  ○ None
│
◇  Dependency injection
│  ● Protocol-based
│  ○ Factory
│  ○ Swinject
│  ○ None
│
◇  Persistence
│  ● Native
│  ○ SwiftData
│  ○ Core Data
│  ○ Realm
│
◇  Image loading
│  ● Native
│  ○ Nuke
│  ○ Kingfisher
│
◇  Environments
│  ◉ Development
│  ◉ Staging
│  ◉ Production
│
◇  Code quality
│  ◉ SwiftLint
│  ◉ SwiftFormat
│  ◯ Periphery
│
◇  CI provider
│  ● GitHub Actions
│  ○ None
│
◇  Generate project?
│  Yes
│
└  Project created successfully
```

Objective-C 時自動改成：

```text
◇ Networking
│  ● URLSession
│  ○ AFNetworking
│  ○ None

◇ Code quality
│  ◉ Strict Clang Warnings
│  ◉ clang-format
│
◇ Header strategy
│  ● Modules
│  ○ Prefix Header
│
◇ Nullability
│  ● Enabled
│  ○ Disabled
```

---

## 13. CLI Command Contract

### 13.1 建立專案

```bash
xscaffold init
xscaffold init MyApp
xscaffold init --config scaffold.yml
```

非互動：

```bash
xscaffold init MyApp \
  --platform ios \
  --language swift \
  --ui swiftui \
  --architecture clean \
  --deployment-target 17.0 \
  --generator xcodegen \
  --yes
```

重要參數：

```text
--config <path>
--destination <path>
--preset <name>
--interactive
--no-interactive
--dry-run
--force
--skip-bootstrap
--skip-git
--skip-build-validation
--output <text|json>
```

### 13.2 驗證設定

```bash
xscaffold validate scaffold.yml
xscaffold validate scaffold.yml --strict
xscaffold validate scaffold.yml --output json
```

驗證層級：

1. Schema validation。
2. Compatibility validation。
3. Template availability。
4. Dependency compatibility。
5. Environment validation。

### 13.3 預覽生成計劃

```bash
xscaffold plan --config scaffold.yml
xscaffold plan --config scaffold.yml --output json
```

必須顯示：

- 使用模板。
- 套用 Layer。
- 新增檔案。
- 覆蓋檔案。
- 合併檔案。
- 執行命令。
- 警告。
- 衝突。

### 13.4 環境診斷

```bash
xscaffold doctor
xscaffold doctor --config scaffold.yml
xscaffold doctor --output json
```

依據設定檔只檢查必要工具。

### 13.5 新增能力

```bash
xscaffold add feature Profile
xscaffold add service Analytics
xscaffold add target WidgetExtension
xscaffold add package Alamofire
xscaffold add integration FirebaseCrashlytics
```

### 13.6 重新產生

```bash
xscaffold generate
```

只重新產生受控檔案，例如：

- `project.yml`。
- `.xcconfig`。
- CI Workflow。
- Makefile。
- SwiftLint。
- SwiftFormat。
- clang-format。
- Fastlane。
- Generated source。

預設不覆蓋業務程式碼。

---

## 14. 第三方套件策略

### 14.1 原則

不採用以下極端方案：

- 所有套件全部內建。
- 所有套件全部交給使用者建立後自行加入。

採用：

> 架構型與工具型套件由初始化流程支援；業務型 SDK 透過 Integration 指令加入；任意套件允許使用者自行加入。

### 14.2 三層分類

#### A. 架構型與工具型套件

可在初始化時選擇：

- Alamofire。
- AFNetworking。
- Factory。
- Swinject。
- Realm。
- Nuke。
- Kingfisher。
- SwiftLint。
- SwiftFormat。
- Periphery。
- SnapshotTesting。
- CocoaLumberjack。
- Masonry。
- clang-format。

#### B. 一般功能套件

互動式可選，但預設不加入：

- Networking provider。
- DI provider。
- Persistence provider。
- Image loading provider。
- Logging provider。

#### C. 業務型整合

透過：

```bash
xscaffold add integration <name>
```

例如：

- Firebase。
- Firebase Crashlytics。
- RevenueCat。
- AppsFlyer。
- Adjust。
- Agora。
- LINE SDK。
- Google Maps。
- Stripe。
- 公司內部 SDK。

### 14.3 Package 與 Integration 差異

```text
Package
    Dependency declaration
    Target dependency
    Version requirement

Integration
    Package
    + 初始化程式
    + Build Phase
    + Config placeholder
    + Entitlement
    + URL Scheme
    + Privacy configuration
    + README instructions
```

---

## 15. Package Registry

```yaml
packages:
  alamofire:
    name: Alamofire
    url: https://github.com/Alamofire/Alamofire.git
    requirement:
      type: upToNextMajor
      minimum: "5.10.0"
    supports:
      platforms:
        - ios
        - macos
      languages:
        - swift
    capabilities:
      - networking

  factory:
    name: Factory
    url: https://github.com/hmlongco/Factory.git
    requirement:
      type: upToNextMajor
      minimum: "2.5.0"
    supports:
      languages:
        - swift
    capabilities:
      - dependency-injection
```

規則：

- 套件 URL 與版本集中管理。
- 模板不直接硬編版本。
- Registry 中的版本更新需有測試。
- 套件必須宣告平台與語言相容性。
- 未知套件以 Custom Package 保存。

Custom Package：

```yaml
dependencies:
  customPackages:
    - name: MyInternalSDK
      url: git@github.com:company/MyInternalSDK.git
      requirement:
        type: branch
        value: main
```

---

## 16. Feature Provider

設定以能力為主，不以套件名稱為主：

```yaml
features:
  networking:
    provider: alamofire

  dependencyInjection:
    provider: factory

  persistence:
    provider: realm

  imageLoading:
    provider: nuke

  logging:
    provider: oslog
```

Resolver：

```text
networking.alamofire
    ↓
Alamofire package
    ↓
NetworkClient template
    ↓
Request adapter
    ↓
Mock implementation
    ↓
Test support
```

---

## 17. Template 系統

### 17.1 Template Composition

不要為每種組合建立完整模板。

採用：

```text
Base
+ Platform
+ Language
+ Interface
+ Architecture
+ Capability Fragments
```

結構：

```text
Templates
├── Bases
│   └── application
├── Platforms
│   ├── ios
│   └── macos
├── Languages
│   ├── swift
│   ├── objective-c
│   └── mixed
├── Interfaces
│   ├── swiftui
│   ├── uikit
│   └── appkit
├── Architectures
│   ├── minimal
│   ├── mvc
│   ├── mvvm
│   ├── mvvm-c
│   └── clean
└── Capabilities
    ├── github-actions
    ├── fastlane
    ├── swiftlint
    ├── swiftformat
    ├── clang-format
    ├── environments
    ├── testing
    ├── alamofire
    ├── realm
    └── nuke
```

### 17.2 Template Manifest

```yaml
schemaVersion: 1

id: ios-swiftui
name: iOS SwiftUI
version: 1.0.0

compatibility:
  platforms:
    - ios

  productTypes:
    - application

  languages:
    - swift

  interfaces:
    - swiftui

  lifecycles:
    - swiftui

  architectures:
    - minimal
    - mvvm
    - clean

deploymentTargets:
  minimum: "15.0"

capabilities:
  supported:
    - swift-testing
    - xctest
    - swiftlint
    - swiftformat
    - swift-package-manager
    - xcodegen
    - github-actions
    - multiple-environments

files:
  root: Files
```

### 17.3 Conflict Priority

```text
Base
Platform
Language
Interface
Architecture
Capability
Project Override
```

支援策略：

```text
create-only
replace-generated
merge-yaml
merge-json
append
skip
error
```

業務程式碼預設：

```text
create-only
```

工具設定檔可使用：

```text
replace-generated
merge-yaml
```

---

## 18. Generation Flow

```text
Load Configuration
    ↓
Apply Defaults
    ↓
Validate Schema
    ↓
Resolve Compatibility
    ↓
Resolve Dependencies
    ↓
Resolve Templates
    ↓
Build Generation Plan
    ↓
Check Conflicts
    ↓
Create Temporary Workspace
    ↓
Render Files
    ↓
Run Generator
    ↓
Run Formatters
    ↓
Run Build Validation
    ↓
Commit Files
    ↓
Initialize Git
    ↓
Create Initial Commit
```

規則：

- 不可邊詢問邊寫入正式目錄。
- 所有操作先產生 `GenerationPlan`。
- 發生錯誤時執行 rollback。
- 目的目錄不可留下半成品。

Core API：

```swift
public protocol ProjectScaffolding: Sendable {
    func validate(
        configuration: ProjectConfiguration
    ) async -> ValidationResult

    func plan(
        configuration: ProjectConfiguration,
        destination: URL
    ) async throws -> GenerationPlan

    func generate(
        plan: GenerationPlan
    ) async throws -> GenerationResult
}
```

---

## 19. Machine-readable Output

所有主要命令支援：

```bash
--output text
--output json
```

JSON 模式規則：

- stdout 只輸出 JSON。
- stderr 輸出 log。
- 不顯示 ANSI 顏色。
- 禁止互動。
- 失敗時仍輸出合法 JSON。

範例：

```json
{
  "success": true,
  "destination": "/Users/example/Projects/MyApp",
  "projectFile": "/Users/example/Projects/MyApp/MyApp.xcodeproj",
  "generatedFiles": 47,
  "skippedFiles": 0,
  "warnings": [],
  "durationMilliseconds": 1842
}
```

Exit Code：

```text
0   Success
1   Unexpected failure
2   Invalid CLI arguments
3   Configuration parsing failure
4   Configuration validation failure
5   Template resolution failure
6   File conflict
7   Generation failure
8   External command failure
9   Build validation failure
10  Environment requirement missing
130 User cancelled
```

---

## 20. Ownership Manifest

由 `xscaffold` 建立的專案需包含：

```text
.xscaffold
├── manifest.json
├── generated-files.json
├── template-lock.json
└── schema-version
```

範例：

```json
{
  "schemaVersion": 1,
  "scaffoldVersion": "0.1.0",
  "template": {
    "id": "ios-swiftui",
    "version": "1.0.0"
  },
  "generatedFiles": [
    {
      "path": "project.yml",
      "policy": "replace-generated",
      "checksum": "..."
    },
    {
      "path": "Sources/App/App.swift",
      "policy": "create-only",
      "checksum": "..."
    }
  ]
}
```

用途：

- 判斷 generated file。
- 檢查檔案是否被修改。
- 安全執行 regenerate。
- 支援模板升級。
- 支援 migration。
- 高精度重建配置。

---

## 21. 既有專案分析與反向配置

### 21.1 目標

將既有 Xcode 專案推導成：

```text
scaffold.yml
scaffold.import-report.json
```

不是保證完美還原原始建立意圖，而是：

> 描述目前專案主要結構、設定、依賴與工具鏈的可用配置。

### 21.2 指令

```bash
xscaffold inspect .
xscaffold inspect . --output json

xscaffold import .
xscaffold import . --mode conservative
xscaffold import . --mode assisted
```

### 21.3 Inspect

只分析，不修改來源專案。

掃描順序：

1. `.xscaffold`。
2. `scaffold.yml`。
3. `project.yml`／`Project.swift`。
4. `.xcodeproj`／`.xcworkspace`。
5. `Package.swift`／`Package.resolved`。
6. `Podfile`／`Podfile.lock`。
7. `.xcconfig`。
8. Source file extensions。
9. Source imports。
10. Directory structure。
11. CI 與 tooling files。

### 21.4 可精確取得

- Project name。
- Target。
- Product type。
- Platform。
- Deployment target。
- Bundle Identifier。
- Swift version。
- Build configurations。
- Schemes。
- Swift／Objective-C／Mixed。
- Package dependencies。
- CocoaPods。
- Framework dependencies。
- Build phases。
- `.xcconfig`。
- Test targets。
- Entitlements。
- Extensions。
- SwiftLint。
- SwiftFormat。
- clang-format。
- GitHub Actions。
- Fastlane。
- Privacy Manifest。

### 21.5 只能推測

- MVC。
- MVVM。
- MVVM-C。
- Clean Architecture。
- Feature-first。
- Layer-first。
- 環境名稱語意。
- 套件用途。
- 資料夾 ownership。

推測結果必須保存：

```json
{
  "field": "architecture.pattern",
  "value": "mvvm-c",
  "confidence": 0.82,
  "source": "inferred",
  "evidence": [
    "AppCoordinator.swift",
    "ProfileCoordinator.swift",
    "18 ViewModel types detected"
  ]
}
```

### 21.6 Import Mode

#### Conservative

只輸出高確定性資訊。

```bash
xscaffold import . --mode conservative
```

不確定值：

```yaml
architecture:
  pattern: unspecified
```

#### Assisted

允許推測並互動確認。

```bash
xscaffold import . --mode assisted
```

#### AI-assisted

Skill 讀取：

```bash
xscaffold inspect . --output json
```

再分析目錄、README、ADR 與代表性程式碼。

AI 結果仍需通過 Core Validation。

---

## 22. Skill Adapter

### 22.1 結構

```text
Skills
└── xcode-project-scaffold
    ├── SKILL.md
    ├── agents
    │   └── openai.yaml
    ├── scripts
    │   ├── check-xscaffold.sh
    │   ├── validate-config.sh
    │   ├── plan-project.sh
    │   ├── generate-project.sh
    │   └── inspect-project.sh
    └── references
        ├── configuration-schema.md
        ├── compatibility-matrix.md
        ├── package-registry.md
        ├── presets.md
        ├── error-codes.md
        └── examples.md
```

### 22.2 工作流程

```text
理解需求
    ↓
判斷新專案或既有專案
    ↓
收集必要資訊
    ↓
產生 scaffold.yml
    ↓
xscaffold validate --output json
    ↓
修正可自動修正項目
    ↓
xscaffold plan --output json
    ↓
顯示摘要
    ↓
xscaffold init --output json
    ↓
回報結果
```

### 22.3 Skill 與 Code Agent 使用規則

Code Agent 執行時：

1. 優先修改 Core，而不是在 CLI 重複邏輯。
2. 新增 Schema 欄位時同步更新：
   - YAML decoding。
   - Defaults。
   - Validation。
   - JSON output。
   - Reference。
   - Tests。
3. 新增套件時同步更新：
   - Registry。
   - Compatibility。
   - Template fragments。
   - Snapshot tests。
4. 新增模板時必須提供：
   - Manifest。
   - Compatibility。
   - Generated file snapshot。
   - Build validation。
5. 不直接修改 `.pbxproj`。
6. 不繞過 `GenerationPlan` 寫入檔案。
7. 不讓 Skill 自行實作 Core 規則。

---

## 23. Preset

Preset 是預設值集合，不是獨立模板。

### 23.1 `ios-modern`

```yaml
product:
  platform: ios
  deploymentTarget: "17.0"

language:
  primary: swift

interface:
  primary: swiftui

architecture:
  pattern: clean

generator:
  type: xcodegen

features:
  networking:
    provider: urlsession

  dependencyInjection:
    provider: protocol-based

  logging:
    provider: oslog

quality:
  swiftlint:
    enabled: true

  swiftformat:
    enabled: true

testing:
  unit:
    framework: swift-testing
```

### 23.2 `ios-legacy`

```yaml
product:
  platform: ios
  deploymentTarget: "15.0"

language:
  primary: objective-c

interface:
  primary: uikit

architecture:
  pattern: mvc

dependencies:
  managers:
    - cocoaPods

quality:
  clangFormat:
    enabled: true
```

### 23.3 `ios-migration`

```yaml
product:
  platform: ios
  deploymentTarget: "16.0"

language:
  primary: objective-c
  interoperability: swift

interface:
  primary: uikit
  secondary:
    - swiftui

architecture:
  pattern: mvvm-c

dependencies:
  managers:
    - cocoaPods
    - swift-package-manager
```

### 23.4 `macos-modern`

```yaml
product:
  platform: macos
  type: application
  deploymentTarget: "14.0"

language:
  primary: swift

interface:
  primary: swiftui

architecture:
  pattern: mvvm
```

---

## 24. Roadmap

### v0.1.0 — New Project Vertical Slice

#### Core

- [ ] 建立 Swift Package。
- [ ] 建立模組 targets。
- [ ] 定義 Schema models。
- [ ] YAML decode／encode。
- [ ] Default resolution。
- [ ] Compatibility Resolver。
- [ ] Validation Issue。
- [ ] Generation Plan。
- [ ] JSON output。
- [ ] Exit codes。

#### CLI

- [ ] `xscaffold init`。
- [ ] `xscaffold validate`。
- [ ] `xscaffold plan`。
- [ ] `xscaffold doctor`。
- [ ] Interactive Prompt。
- [ ] `--config`。
- [ ] `--dry-run`。
- [ ] `--output json`。

#### First Vertical Template

- [ ] iOS。
- [ ] Swift。
- [ ] SwiftUI。
- [ ] Minimal。
- [ ] XcodeGen。
- [ ] Swift Testing。
- [ ] SwiftLint。
- [ ] SwiftFormat。
- [ ] GitHub Actions。
- [ ] Development／Staging／Production。

#### Validation

- [ ] `xcodegen generate` 成功。
- [ ] `xcodebuild build` 成功。
- [ ] Unit tests 成功。
- [ ] SwiftLint 成功。
- [ ] SwiftFormat lint 成功。

### v0.2.0 — Template Expansion

- [ ] iOS UIKit Swift。
- [ ] macOS SwiftUI Swift。
- [ ] macOS AppKit Swift。
- [ ] iOS UIKit Objective-C。
- [ ] CocoaPods。
- [ ] clang-format。
- [ ] Strict Clang Warnings。
- [ ] Package Registry。
- [ ] Feature Provider。
- [ ] `xscaffold add package`。
- [ ] `xscaffold add feature`。
- [ ] Ownership Manifest。
- [ ] `xscaffold generate`。

### v0.3.0 — Mixed and Import

- [ ] iOS Mixed。
- [ ] macOS Objective-C。
- [ ] macOS Mixed。
- [ ] `xscaffold inspect`。
- [ ] `xscaffold import`。
- [ ] Conservative Import。
- [ ] Assisted Import。
- [ ] Package detection。
- [ ] Tooling detection。
- [ ] Environment detection。
- [ ] Import Report。

### v0.4.0 — Skill and Migration

- [ ] Skill Adapter。
- [ ] AI-assisted Import。
- [ ] Architecture inference。
- [ ] Integration Registry。
- [ ] `xscaffold add integration`。
- [ ] Template migration。
- [ ] Config migration。
- [ ] Project standardization report。

### v1.0.0

- [ ] 穩定 Schema。
- [ ] 穩定 CLI Contract。
- [ ] 穩定 JSON output。
- [ ] 完整文件。
- [ ] Homebrew distribution。
- [ ] Release automation。
- [ ] Template compatibility policy。
- [ ] Skill package。
- [ ] End-to-end tests。

---

## 25. 開發執行順序

### Milestone 1：Package Foundation

- [ ] 建立 `Package.swift`。
- [ ] 建立所有核心 targets。
- [ ] 加入 Swift Argument Parser。
- [ ] 加入 YAML library。
- [ ] 建立 CI。
- [ ] 建立 coding conventions。

驗收：

```bash
swift build
swift test
```

### Milestone 2：Schema

- [ ] 建立 `ProjectConfiguration`。
- [ ] 建立所有 enum。
- [ ] 建立 Defaults。
- [ ] 建立 YAML parsing。
- [ ] 建立 round-trip tests。

驗收：

```text
YAML → Swift Model → YAML
```

語意一致。

### Milestone 3：Compatibility

- [ ] Platform Rule。
- [ ] UI Rule。
- [ ] Language Rule。
- [ ] Architecture Rule。
- [ ] Testing Rule。
- [ ] Quality Tool Rule。
- [ ] Dependency Rule。

驗收：

```text
macOS + UIKit
    → XS1001

iOS + AppKit
    → XS1002

Objective-C + Swift Testing
    → XS1201

iOS SwiftUI + Clean
    → Valid
```

### Milestone 4：CLI Skeleton

- [ ] Root Command。
- [ ] `validate`。
- [ ] `plan`。
- [ ] `doctor`。
- [ ] JSON output。
- [ ] Exit codes。

此階段先不生成專案。

### Milestone 5：Template Resolver

- [ ] Template Manifest。
- [ ] Template discovery。
- [ ] Layer composition。
- [ ] Capability matching。
- [ ] Conflict detection。
- [ ] GenerationPlan。

### Milestone 6：First Vertical Slice

只完成：

```text
iOS
Swift
SwiftUI
Minimal
XcodeGen
Swift Testing
```

驗收：

```bash
xscaffold init DemoApp \
  --preset ios-modern \
  --destination /tmp/DemoApp
```

並執行：

```bash
xcodegen generate

xcodebuild \
  -project DemoApp.xcodeproj \
  -scheme DemoApp \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  build
```

### Milestone 7：Interactive Prompt

- [ ] Text Prompt。
- [ ] Select Prompt。
- [ ] Multi Select。
- [ ] Confirm。
- [ ] Keyboard navigation。
- [ ] Ctrl+C。
- [ ] Non-TTY fallback。

Prompt 必須從 Resolver 取得 available options。

### Milestone 8：Dependency Registry

- [ ] Package Schema。
- [ ] Registry loader。
- [ ] Feature Provider Resolver。
- [ ] Compatibility。
- [ ] Package fragment。
- [ ] Custom Package。

### Milestone 9：Other Templates

依序：

1. iOS UIKit Swift。
2. macOS SwiftUI。
3. macOS AppKit。
4. iOS UIKit Objective-C。

### Milestone 10：Ownership and Regeneration

- [ ] Manifest。
- [ ] Checksum。
- [ ] Generated file policy。
- [ ] `generate`。
- [ ] Safe overwrite。
- [ ] Template lock。

### Milestone 11：Inspector

- [ ] Project detection。
- [ ] XcodeGen detection。
- [ ] Tuist detection。
- [ ] SPM detection。
- [ ] CocoaPods detection。
- [ ] Language detection。
- [ ] UI detection。
- [ ] Environment detection。
- [ ] Tooling detection。

### Milestone 12：Skill Adapter

CLI 穩定後實作。

---

## 26. 第一批 GitHub Issues

```text
XS-001 Initialize Swift package structure
XS-002 Define ScaffoldSchema models
XS-003 Add YAML encoding and decoding
XS-004 Add configuration defaults
XS-005 Define stable validation issue format
XS-006 Implement platform and UI compatibility rules
XS-007 Implement language and testing compatibility rules
XS-008 Implement architecture compatibility rules
XS-009 Create xscaffold root command
XS-010 Implement validate command
XS-011 Implement JSON output format
XS-012 Define CLI exit codes
XS-013 Implement plan command
XS-014 Define template manifest schema
XS-015 Implement template discovery
XS-016 Implement template resolver
XS-017 Implement generation plan builder
XS-018 Implement file conflict policies
XS-019 Implement generation transaction
XS-020 Create iOS SwiftUI minimal template
XS-021 Add XcodeGen integration
XS-022 Add xcodebuild validation
XS-023 Implement interactive text prompt
XS-024 Implement interactive select prompt
XS-025 Implement interactive multi-select prompt
XS-026 Add ios-modern preset
XS-027 Define package registry schema
XS-028 Implement package registry loader
XS-029 Implement feature provider resolver
XS-030 Implement ownership manifest
XS-031 Implement generate command
XS-032 Implement inspect command skeleton
XS-033 Implement import report model
XS-034 Add Skill Adapter skeleton
```

---

## 27. Code Agent 工作規範

### 27.1 每個 Issue 的輸出

Code Agent 每次處理 Issue 必須提供：

1. 變更摘要。
2. 設計決策。
3. 修改檔案。
4. 新增測試。
5. 執行指令。
6. 測試結果。
7. 未完成事項。
8. 風險或後續建議。

### 27.2 實作原則

- 不跨越模組責任。
- 不在 CLI 中重複 Core 規則。
- 不在 Prompt 中硬編相容性。
- 不直接編輯 `.pbxproj`。
- 不在正式目錄邊生成邊修改。
- 所有寫入必須經過 `GenerationPlan`。
- 所有外部命令必須經過 `ProcessRunner`。
- 所有 File System 操作必須可替換與測試。
- 所有新增 Schema 都必須有 Codable tests。
- 所有新增 Validation Rule 都必須有正反案例。
- 所有模板都必須有 snapshot 與 build validation。
- JSON output 必須保持 backward compatibility。

### 27.3 Commit 建議

```text
feat(schema): add project configuration model
feat(validation): add UI platform compatibility rules
feat(cli): add validate command
feat(template): add iOS SwiftUI base template
test(generator): add generated project build validation
docs(schema): document scaffold.yml fields
```

---

## 28. 測試策略

### Unit Tests

- Schema。
- Defaults。
- YAML parsing。
- Compatibility。
- Validation。
- Package Registry。
- Feature Resolver。
- Template Resolver。
- Conflict Policy。
- Inspector rules。

### Snapshot Tests

- `scaffold.yml`。
- Template output。
- JSON CLI output。
- Generation Plan。
- Import Report。

### Integration Tests

- XcodeGen generation。
- CocoaPods generation。
- Swift Package dependencies。
- Objective-C template。
- Mixed template。
- Git initialization。
- Build validation。

### End-to-End Tests

```text
CLI Input
    ↓
Configuration
    ↓
Validation
    ↓
Plan
    ↓
Generation
    ↓
XcodeGen
    ↓
xcodebuild
```

---

## 29. Definition of Done

### v0.1 完成條件

執行：

```bash
xscaffold init DemoApp
```

可透過互動選擇：

```text
iOS
Swift
SwiftUI
Minimal
iOS 17
XcodeGen
Swift Testing
SwiftLint
SwiftFormat
GitHub Actions
```

並產生：

```text
DemoApp
├── App
├── Sources
├── Resources
├── Tests
├── Config
├── .github
├── .xscaffold
├── .swiftlint.yml
├── .swiftformat
├── project.yml
├── scaffold.yml
├── Makefile
└── README.md
```

必須通過：

```bash
xcodegen generate
xcodebuild build
swift test
swiftlint
swiftformat --lint .
```

### v1.0 完成條件

- 新專案可透過 CLI、設定檔與 Skill 建立。
- 支援 iOS、macOS、Swift、Objective-C、Mixed。
- 主要模板通過 build validation。
- 支援 Package Registry。
- 支援 Integration。
- 支援 Ownership Manifest。
- 支援既有專案 Inspect 與 Import。
- 支援 Machine-readable JSON。
- 可由 Homebrew 安裝。
- Schema 與 CLI Contract 具版本策略。
- 文件可供人類與 Code Agent 直接使用。

---

## 30. 最終決策

```text
Project
    xcode-project-scaffold

Executable
    xscaffold

Architecture
    CLI Core + Skill Adapter

Core Contract
    scaffold.yml

Generator
    XcodeGen first
    Tuist later

Initial Platforms
    iOS
    macOS

Initial Languages
    Swift
    Objective-C

Later Language Mode
    Mixed Swift + Objective-C

Dependency Strategy
    Capability-first
    Registry-backed
    Package and Integration separated

Existing Project Support
    inspect
    import
    ownership manifest

Primary Goal
    Reproducible and AI-ready Xcode project lifecycle tooling
```

第一個實作目標不是一次支援所有組合，而是完成一條可編譯、可測試、可重現的垂直切片：

```text
iOS + Swift + SwiftUI + Minimal + XcodeGen
```

完成後再依序擴展平台、語言、架構、套件、Inspector 與 Skill。
