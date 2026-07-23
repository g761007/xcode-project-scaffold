# project.yml 由 Swift 型別建構後序列化

`project.yml` 以專案自建的一小組 Swift 型別建構，再用 Yams 序列化輸出。不使用樣板引擎（Stencil / Mustache），也不相依 XcodeGen 的 `ProjectSpec` / `XcodeGenKit` 函式庫。XcodeGen 以子行程呼叫。

## 為什麼

`project.yml` 是結構化資料，不是文字。用文字樣板加條件語法產生 YAML，會讓「三環境可選」這種需求變成縮排與空白的問題，測試也只能比對字串；計劃早期版本因此需要一整套 `merge-yaml` 衝突合併策略，這個決策讓那套東西完全不必存在——可選區塊退化成一個普通的 Swift 條件式。

不相依 XcodeGen 函式庫，是因為 `XcodeGenKit` 會連帶吃進鎖死在特定版本的 `XcodeProj`，以及 PathKit、JSONUtilities、SwiftCLI、Rainbow 等傳遞相依。那讓 xscaffold 的建置變重，且上游升級會直接衝擊本專案。生成的專案本來就需要一份可自給自足的 `project.yml`（使用者之後會自己跑 `xcodegen generate`），所以輸出 YAML 是必要的，用函式庫反而要多繞一步。

## 代價

XcodeGen 新增或變更 spec 欄位時，需要手動跟進本專案的型別。這個成本由整合測試把關：CI 會實際執行 `xcodegen generate` 與 `xcodebuild test`，上游若改到不相容處會直接失敗。
