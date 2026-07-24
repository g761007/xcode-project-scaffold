# Architecture overlay 生成一個具體範例，取代 App 主畫面

v0.2 的 architecture overlay 從「只產文件」升級成「生成一個實際串起來的具體範例」。範例**取代 App 的主畫面**，而非在旁邊另加一個平行模組。overlay 仍只加原始碼檔案，**不變換 XcodeGen spec、不新增 target**——MVVM 與 MVVM-C 都在單一 app target 內完成。是否生成由 `scaffold.yml` 的 `architecture.includeExample` 控制；關閉時退回只產文件＋Mermaid 架構圖，且**不生空資料夾**。

## 為什麼

只產文件的 overlay 在磁碟上與 `minimal` 沒有差別，撐不起「支援 MVVM」這個版本主張。另一個極端——生一堆 `ViewModelProtocol` / `BaseView` 之類的抽象基底層——正是計劃 §7.4 點名的最典型 scaffold 垃圾，開專案第一件事就是刪掉它們。

中間路線是一個可運作的垂直切片：MVVM 是 View + 具體 ViewModel；MVVM-C 再加一個 `AppCoordinator` 與最小的 2 畫面 list → detail 流程。它是可以直接刪或擴充的實作程式碼，不是抽象層。**取代主畫面**而非另加模組，換到的是：範例就是 App 真正的起始畫面，沒有「刪掉範例」的雜務，而且每個組合都保證能 `build` 與 `test`。

MVVM 與 MVVM-C 仍是單一 app target，所以計劃 §15 那個「overlay 要不要升級成 XcodeGen spec 變換器」的分叉，這輪明確判定為**不需要**——spec 變換是 Clean／模組化（多 target、多 package）才會逼出的需求，延到真的做 Clean 時再有實際案例可判斷。

`includeExample: false` 刻意不生空資料夾：空目錄在 git 裡不存在（要塞 `.gitkeep`），資料夾只在有真的程式碼要放進去時才隨範例一起出現。這與 [ADR-0001](0001-scaffold-yml-as-birth-certificate.md) 下「不留下沒有消費者的空殼」是同一種節制。

## 代價

overlay 現在要為每個 `(pattern, interface)` 組合帶一組範例模板與一張 Mermaid 關係圖，模板量與契約 snapshot 隨組合成長。

`architecture.includeExample` 成為 `scaffold.yml` 的新欄位，牽動預設值、YAML 編解碼、驗證、JSON output、`configuration-schema.md` 與測試（§18.2）。

「取代主畫面」意味著 `pattern × includeExample` 會改變 App 入口的程式碼，因此這些 `on` 組合必須進 E2E，實際 `build`/`test` 以防範例編不過——CI 的 E2E 從 v0.1 的 2 組增為 5 組。
