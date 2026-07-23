# 模板編進二進位檔，不隨附資源套件

`Templates/` 由 `Scripts/embed-templates.py` 轉成 `Sources/ScaffoldCore/Generated/EmbeddedTemplates.swift` 並提交進版控。`Templates/` 仍是撰寫與審查模板的地方；產生檔只是它的鏡像。CI 會重新產生並在結果不同時失敗。

## 為什麼

`xscaffold` 的安裝方式是複製單一檔案到 `~/.local/bin`。若模板是 SwiftPM 資源套件，它會是執行檔旁邊的另一個目錄，安裝時留在原地；而 SwiftPM 產生的 `Bundle.module` 在套件缺席時的反應是 **`fatalError`**——不是可處理的錯誤，是帶著內部訊息的崩潰。實測確認：把 bundle 移開後執行檔輸出 `Fatal error: could not load resource bundle` 隨即終止。

編進二進位檔讓這個失敗模式完全不存在。單一自足執行檔，複製到哪裡都能用。

這也讓 §1 的可重現性主張不依賴「隔壁目錄存在」——同一個執行檔在任何機器上帶著同一份模板。

## 代價

多一個建置步驟，以及一份提交進版控的產生檔。兩者都由 CI 的同步檢查看住：`make templates` 後若 `git diff` 非空即失敗，所以產生檔不可能與 `Templates/` 脫節。

產生檔本身不適合閱讀，但它不需要被閱讀——`Templates/` 才是模板的來源，diff 也該看那裡。
