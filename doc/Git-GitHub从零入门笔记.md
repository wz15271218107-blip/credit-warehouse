# Git & GitHub 从零入门笔记（Day 0）

> 目标：从 0 在 GitHub 上创建一个仓库，把本地文件上传上去。
> 写作日期：2026-10-28 · 对应项目：credit-warehouse

---

## 一、先建立心智模型：Git 和 GitHub 是两回事

这是整个入门最重要的一句话，先想明白再动手：

- **Git**：装在**你电脑上**的工具。作用：给文件夹"拍快照"（存版本）。你改文件、存一版、再改、再存一版，任何时候都能回到任意一版。**像游戏的存档功能。**
- **GitHub**：一个**网站**（云端）。作用：把 Git 拍的快照传到"云保险柜"存一份，电脑坏了不丢，还能给别人看/协作。**像云端存档服务器。**

**一句话记忆：Git 是本地存档工具，GitHub 是云端仓库网站。**
**流程记忆：本地存档（git）→ 告诉它云端地址（remote）→ 上传（push）。**

---

## 二、全流程逻辑主线（8 步，先看主线再看细节）

```
① 网页上建空仓库（GitHub 网站）
② 配置身份（git config）       ← 存档上写"作者名"
③ 进入项目 + 开启存档（git init）
④ 选中要存的文件（git add .）   ← 放进"暂存区/购物车"
⑤ 拍快照存版本（git commit）    ← "结算"，生成一个版本号
⑥ 定主分支名（git branch -M main）
⑦ 告诉 Git 云端地址（git remote add origin 网址）
⑧ 上传（git push）              ← 本地快照推到 GitHub
```

> 记忆口诀：**配身份 → 开存档 → 加文件 → 拍快照 → 定名字 → 指地址 → 推上去**

---

## 三、每一步详解：命令 + 大白话 + 验证

### 第 ① 步：网页上建空仓库（GitHub 网站操作）

1. 登录 GitHub，右上角 **「+」→ New repository**
2. 仓库名填 `credit-warehouse`
3. **不要勾选** "Add a README file"（保持空仓库）
4. 点 **Create repository**
5. 创建后，复制地址栏网址，格式：
   `https://github.com/你的用户名/credit-warehouse.git`

> 记忆点：仓库名就是你云保险柜的名字；网址就是保险柜的地址。

---

### 第 ② 步：配置身份（只做一次，全局生效）

```powershell
git config --global user.name "zhuowang"
git config --global user.email "3572981664@qq.com"
```

**大白话**：告诉 Git"你是谁"。每次 commit 存档时，都会自动记上这个作者名和邮箱。`--global` = 对你电脑上所有仓库生效，只配一次。

**验证**：

```powershell
git config --global --list
```

能看到 user.name 和 user.email 就对了。

---

### 第 ③ 步：进入项目 + 开启存档

```powershell
cd C:\Users\35729\credit-warehouse
git init
```

- `cd` = 进入项目文件夹（change directory）
- `git init` = 在这个文件夹里**开启存档功能**。执行后文件夹里多出一个隐藏的 `.git` 目录，所有版本记录都存它里面。

**成功标志**：显示 `Initialized empty Git repository in C:/.../credit-warehouse/.git/`

---

### 第 ④ 步：选中要存的文件（暂存区）

```powershell
git add .
```

**大白话**：`.` 表示"当前文件夹里所有文件"。`git add` 把文件**选中**放进"暂存区"（就像超市购物车）——先选好，还没结账。

**注意**：执行后可能看到 `LF will be replaced by CRLF` 的 warning——这是 Windows 换行符的正常提示，**不是错误，不用管**。

---

### 第 ⑤ 步：拍快照，存一个版本

```powershell
git commit -m "Day 0:项目初始化，数据与脚本入库"
```

**大白话**：把暂存区里的文件**正式存成一个版本**（结账）。`-m` 后面引号里是这次版本的备注，方便以后知道"这个版本干了什么"。

**成功标志**：

```
[master (root-commit) 4d25a0f] Day 0:项目初始化，数据与脚本入库
3 files changed, 42613 insertions(+)
```

`4d25a0f` 就是这次版本的**版本号**（每次都会自动生成不同的）。

---

### 第 ⑥ 步：定主分支名

```powershell
git branch -M main
```

**大白话**：分支 = 一条独立的版本线。GitHub 默认主分支叫 `main`，把本地分支重命名成 `main`，两边统一。**没有输出就是成功。**

---

### 第 ⑦ 步：告诉 Git 云端地址

```powershell
git remote add origin https://github.com/wz15271218107-blip/credit-warehouse.git
```

**大白话**：`remote` = 远程仓库；`origin` = 给这个远程地址起的**小名**（叫 origin 是行业惯例）；后面那串 = 云端保险柜的实际地址。**执行这行时没有输出 = 成功！**

**验证**：

```powershell
git remote -v
```

出现两行带 `origin` 的地址（fetch 和 push）就配置好了。

---

### 第 ⑧ 步：上传（push）

```powershell
git push -u origin main
```

**大白话**：把本地 `main` 分支的快照**推到云端**（origin 那个地址）。
`-u` = 记下这个对应关系，以后直接 `git push` 就行，不用再写全。

**成功标志**：

```
Enumerating objects: 7, done.
...
To https://github.com/wz15271218107-blip/credit-warehouse.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

看到 `main -> main` 就成功了！刷新 GitHub 仓库页面能看到文件。

---

## 四、认证：token 是什么、怎么生成、怎么用

### 为什么 push 不能用密码？

GitHub 从 2021 年起**禁止用账号密码**登录命令行，必须用 **Personal Access Token（个人访问令牌）**。**token = 一串 `ghp_` 开头的密码**，可以理解为"给命令行用的专用密码"。

### 生成步骤（网页操作）

1. GitHub 右上角头像 → **Settings**
2. 最底部左边 → **Developer settings**
3. **Personal access tokens → Tokens (classic)** → **Generate new token (classic)**
4. Note 填名字（如 `my-pc`），Expiration 选 90 days
5. 勾选权限：点 **repo** 前面的勾（整组选上）
6. 点 **Generate token**
7. **立刻复制保存**那串 `ghp_` 开头的字符串（**只显示一次，关掉就没了！**）

### 输入时的关键细节

push 弹出认证时：

- `Username` → 输入你的 GitHub 用户名
- `Password` → **粘贴 token**（注意：粘贴后屏幕不显示任何字符，**这是正常的**，不要以为没粘上，直接回车）

---

## 五、常见报错问答集（我们实际踩过的坑）

### Q1：push 报 `fatal: 响应状态代码不指示成功：401 (Unauthorized)`

**现象**：认证失败。

**原因**：认证窗口 Password 处 token 没真正粘贴进去（要么直接回车了，要么粘贴没生效）。

**解决**：重新 `git push`，Password 处**右键粘贴 token 再回车**。粘贴后无显示是正常的，粘完直接回车。

---

### Q2：push 报 `Failed to connect to github.com port 443 / Connection was reset`

**现象**：连不上 GitHub，超时或被重置。

**原因**：**VPN 只代理了浏览器，没有代理 git 命令行**。Windows 上 git 默认不读系统代理设置，必须显式配置。

**解决**（两步）：

```powershell
git config --global http.proxy http://127.0.0.1:7897
git config --global https.proxy http://127.0.0.1:7897
```

- `7897` 是你的 Clash 系列 VPN 的本地代理端口（查法：VPN 设置里的 HTTP 端口；或看系统代理 `HKCU:\...\Internet Settings` 的 ProxyServer）
- 配完重新 push 即可

---

### Q3：PowerShell 不能粘贴命令

**原因**：经典 PowerShell 窗口默认没开"快速编辑模式"。

**解决**：右键**窗口标题栏** → 属性 → 选项 → 勾选 **快速编辑模式** → 确定。之后**单击右键 = 粘贴**。（Win11 推荐直接用 Windows Terminal，原生支持 Ctrl+V。）

---

### Q4：PowerShell 卡住，按回车没反应

**解决**：按 **Ctrl + C** 取消当前命令/输入，回到提示符。还不行就关掉窗口重开——**已执行成功的 git 操作不会丢**（都写在 `.git` 目录里了），重开后 `cd` 进项目继续即可。

---

### Q5：删除旧 token、生成新的，会不会断开仓库？

**不会**。token 只是 push 时的身份凭证，不在仓库地址里、不影响已上传的文件。删除后唯一影响：下次 push 要用新 token 认证。如果 Git 缓存了旧凭据导致 401，执行：

```powershell
git credential-manager erase
```

清掉缓存，重新 push 输新 token。

---

### Q6：下载大文件卡住 / BITS 报"游戏模式"错误

**现象**：PowerShell 下载 CSV 到一半卡死；BITS 下载报"活动游戏模式接收人，作业被暂停"。

**原因**：http 通道不稳；BITS 被游戏进程干扰。

**解决**：写 Python 脚本用 urllib 走 HTTPS + 断点续传下载（本项目的 `scripts/download_data.py` 可复用）。

---

## 六、高频检查命令速查表

| 命令 | 作用 | 什么时候用 |
|---|---|---|
| `git status` | 看当前哪些文件改了/没提交 | 每次动手前看状态 |
| `git log --oneline` | 看提交历史（版本号+备注） | 想确认存过哪些版本 |
| `git remote -v` | 看云端地址配好没 | remote 后验证 |
| `git config --global --list` | 看身份配置 | 配完验证 |
| `git push` | 上传 | 每天提交后 |
| `git pull` | 从云端拉最新（以后会用到） | 换电脑/协作时 |

---

## 七、给自己的三条铁律

1. **token 是密码级凭证**：只在认证窗口输入，绝不发给任何人、绝不写进任何文件/聊天记录。一旦泄露立即去 Settings 删除重新生成。
2. **每天结束必须 commit + push**：项目要持续提交到 GitHub，这是数据开发岗的基本职业习惯，也是面试时能展示的实打实的仓库。
3. **报错先读原文再查**：git 的报错英文/中文都很直白，把报错原文发导师或搜索，不要凭感觉乱改。
