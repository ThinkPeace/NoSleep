# NoSleep 发布流程

1. 确保 `main` 分支的 `nosleep` 与脚本已就绪。
2. 打 tag：`git tag vX.Y.Z`。
3. 推送 tag：`git push origin vX.Y.Z`。
4. GitHub Actions 会自动生成并上传 Release 资产：
   - `nosleep-X.Y.Z`
   - `nosleep-X.Y.Z.sha256`
5. 更新 Homebrew tap 的 formula，替换为新版本的 URL 和 sha256。
