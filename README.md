# 清流 iOS 客户端

自签可装的 iOS 端：登录/填订阅 → 拉节点 → 一键丢进代理客户端。构建全在 CI 上跑（不需要 Mac），产物是**未签名 IPA**，你在手机上用签名工具签完就能装。

---

## 一、先把「自签名」这件事说清楚

iOS 装 App 只有三条路：App Store、TestFlight、**自己签名**。自签的本质是：拿一张开发者证书（含你的 Apple ID 或某个企业的），给 App 重新签名并配一份描述文件（provisioning profile），让 iOS 认它是「合法的」。

决定你能干什么的不是签名工具，而是**证书类型 + 权限**：

| 方式 | 成本 | 有效期 | 能开 NetworkExtension（真 VPN） | 适用 |
|---|---|---|---|---|
| 免费 Apple ID（Xcode 个人团队） | 0 | **7 天**，到期重签 | **不能** | 自己调试、短用 |
| 付费开发者 $99/年（个人/公司） | 约 ¥700/年 | 证书 1 年，装一次可用很久 | **能** | 想做成真 VPN 客户端 |
| 企业证书（$299 企业账号，或买共享企业签） | 黑市 ¥几十~几百/年 | 随时被苹果吊销 | 能，但随时失效 | 外挂/灰色分发常用 |
| 超级签名（按 UDID 注册） | 按设备数计费 | 一年，但受 100 台/年限制 | 能 | 少量分发 |
| TrollStore（巨魔） | 0 | **永久**，不用签 | 能（用它自己的方式注入） | iOS 14.0–16.6.1 / 17.0，需对应漏洞 |

**关键结论**：NetworkExtension（系统级 VPN 隧道）这个 entitlement，免费证书**申请不到**，必须有付费开发者账号。所以：

- 如果你要的是「一个 App，点一下就连上」→ 必须 $99 账号，没有捷径。
- 如果你要的是「自己做壳、管订阅、换节点，隧道交给现成客户端」→ 免费证书就能装，本项目就是这条。

---

## 二、那些 CF 外挂的 iOS 版是怎么发的

你问的那些 CF/穿越火线辅助 IPA，路子基本就四种，跟技术无关，跟签名有关：

1. **企业签 + 分发页**：买一张企业证书批量签，做一个网页，用户点「安装」走 `itms-services://` 拉描述文件。装完要去「设置 → 通用 → VPN与设备管理」点信任。**证书一被苹果吊销，全站用户当天全挂**——所以你会看到它们隔三差五让你重装。
2. **超级签名**：你把 UDID 给它，它用你的 UDID 单独签一份。稳定但贵，一台一年，100 台上限。
3. **TestFlight**：合规、稳，但苹果审核会拦外挂，所以只用于擦边合规的工具。
4. **巨魔 / 注入**：TrollStore 直接装未签名 IPA（利用 CoreTrust 漏洞，免签名永久可用）；或先用 TrollFools 把 dylib 注入一个已装的正版 App。**这条路只在特定 iOS 版本上成立**，且不越狱也能用，所以外挂圈特别爱它。

共同点：**它们都没有绕开苹果的签名体系，只是选了最便宜/最不稳的那张证书**。所以「学它们怎么做」= 学它的分发管道，不是学什么技术魔法。

我们自己用不上企业签（有被吊销风险，而且企业证书不能公开分发），用第 1 条里的免费自签或巨魔就够。

---

## 三、构建（不用 Mac）

推上 GitHub，Actions 自动出 IPA：

```bash
cd qingliu-ios
git init && git add -A && git commit -m "qingliu ios client"
git remote add origin git@github.com:<你>/qingliu-ios.git
git push -u origin main
```

跑完在 Actions → 这次的 run → Artifacts 下载 `QingliuVPN-unsigned.ipa`。

本地想验证工程能不能生成（不需要 Xcode 也能跑 xcodegen，但要 macOS 才能 build）：

```bash
brew install xcodegen && xcodegen generate
```

---

## 四、手机上安装（三选一）

### A. 免费 Apple ID + AltStore / SideStore（7 天）

1. 电脑装 AltServer（Win/Mac 都行），iPhone 装 AltStore。
2. 用 Apple ID 登录 AltStore → 导入 `QingliuVPN-unsigned.ipa` → 它自动签、自动装。
3. 每 7 天连同一 Wi-Fi 自动刷新一次，别让后台被系统清掉。

### B. 付费开发者账号（推荐，一年签一次）

1. Apple Developer 后台建 App ID `com.qingliu.vpn`。
2. 用 **Sideloadly / ESign / 轻松签** 导入 p12 证书 + 描述文件，选 IPA，签，装。
3. 装完在「设置 → 通用 → VPN与设备管理」信任证书。

### C. TrollStore（iOS 14.0–16.6.1 / 17.0）

1. 装 TrollStore（按对应版本的方法）。
2. 直接把 `QingliuVPN-unsigned.ipa` 拖进去安装 —— **不用签、不过期**。
3. 前提是系统版本在支持范围内，超出就老实走 A/B。

> 装完打开 App：设置 → 填订阅地址 → 保存并拉取 → 「导入到 Shadowrocket / Stash / sing-box」。

---

## 五、想升级成「真 VPN」

要自己起隧道，加一个 NetworkExtension target：

```
目标 QingliuVPN → + Target: Network Extension → Packet Tunnel Provider
Capabilities: Network Extensions、App Groups（group.com.qingliu.vpn）
```

`Tunnel/PacketTunnelProvider.swift` 里有骨架（sing-box / WireGuard 内核都能塞进去）。**必须有付费开发者账号才能签名并上真机**，否则系统直接拒绝。

---

## 六、注意

- 订阅 token 存在 UserDefaults，不加密。别把 IPA 连同 token 一起传给别人。
- 订阅拉取统一用 `clash-verge` UA，多数面板靠 UA 决定返回 Clash YAML 还是 base64 列表。
- 这个 App 不做流量绘制、不上报任何东西；节点列表只在内存与 UserDefaults。
