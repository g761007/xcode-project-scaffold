# AppKit variant 以程式碼建構，零 storyboard、零 XIB

v0.3 的 `macos-appkit` variant 純以程式碼建構使用者介面與**選單列**：進入點是 `NSApplicationDelegate`，主視窗以 `NSWindow` / `NSWindowController` 建立，選單列以 `NSMenu` 在程式碼中組出。生成專案**不含** `Main.storyboard`，也**不含** `MainMenu.xib`。

## 為什麼

這是 v0.1 §8（UIKit 零 storyboard）的同一條理由，套到 AppKit：選 XcodeGen 的核心動機是避開 `.pbxproj` 這類機器產 XML 的 merge conflict，而 `MainMenu.xib` 與 `Main.storyboard` 是**一模一樣的問題**——同樣機器產、同樣是 XML、同樣會在多人同時改動介面時炸開。前門（`.pbxproj`）擋了，後門（`.xib`／`.storyboard`）開著就沒有意義。

AppKit 的差別在於：Xcode 26.4 的內建 AppKit 樣板預設用 `MainMenu.xib` 承載整條選單列（App / File / Edit / …），並以 `NSApplicationMain` 從該 nib 啟動。因此「零 XIB」對 AppKit 不只是省掉一個空 storyboard，而是要**在程式碼裡把標準選單列建出來**——這是 AppKit 相對 UIKit 多出來的一段。仍然值得：選單列是往後每天可能被改的檔案，把它留在 XML 裡等於把最會產生衝突的東西留在最糟的格式。

以程式碼建構也讓 variant 與 `project.yml` 的「描述只有一份」原則一致：介面結構在 Swift 裡決定，而不是散落在一個 XcodeGen 不經手、diff 不友善的 nib。

## 代價

比 Xcode 內建樣板多一段樣板碼：要手寫一條標準選單列（至少 App 選單的 About／Quit、Edit 選單的剪下／複製／貼上），以及視窗的建立與顯示。內建樣板用 `MainMenu.xib` 幾行就帶過，程式碼版較長。

生成的專案與開發者熟悉的「File → New → macOS App」樣板長得不一樣——第一次打開會找不到 `MainMenu.xib`。生成 README 需說明選單列在何處以程式碼建立。

標準選單列的完整度是一個取捨點：範例只鋪最小可用的選單（App／Edit），不追求重現 Xcode 樣板的整條預設選單。需要更多選單項的人在生成後自行擴充——`AppDelegate` 裡的 `NSMenu` 就是他們要動的地方。
