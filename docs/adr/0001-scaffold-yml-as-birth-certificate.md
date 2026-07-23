# scaffold.yml 是出生證明，不是終身真實來源

`scaffold.yml` 只在專案生成的當下作為輸入。生成完成後，`project.yml` 接手成為專案的真實來源，`scaffold.yml` 僅作為「這個專案由哪份設定產生」的紀錄保存。因此 xscaffold **不**提供重新生成、**不**維護 ownership manifest 或檔案 checksum、**不**管理已存在的專案。

## 為什麼

`scaffold.yml` 永遠追不上 XcodeGen 的表達力。要讓它成為終身真實來源，就必須把 XcodeGen 的 project spec 逐步鏡射進 `scaffold.yml`，最終得到一個更差的 XcodeGen；不然就得開一個 raw override 逃生口，而逃生口一開，可重現性就有洞。真實專案一定會長出工具沒預料到的東西。

把邊界劃在「開場」而不是「終身管理」，換到的是：可重現性沒有例外、沒有檔案所有權問題、沒有三方合併，以及一個小到能真正完成的工具。

## 代價

產品定位從「Xcode 專案生命週期管理工具」降級為「Xcode 專案初始化工具」。以下能力因此不存在：`xscaffold generate` 重新生成、模板升級、設定遷移、`.xscaffold` ownership manifest、既有專案的 `inspect` 與 `import`、`add` 系列指令。

若日後要恢復其中任何一項，需要重新檢視這份決策——它們全都預設 xscaffold 對專案有持續的所有權。
