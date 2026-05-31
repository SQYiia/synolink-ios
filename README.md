# SynoLink iOS

群晖 NAS 原生 iOS 客户端，使用 SwiftUI 构建。

## 功能

- **服务器管理**: 添加/删除 NAS 服务器，自动检测在线状态
- **文件浏览**: 浏览共享文件夹、上传/下载/重命名/删除文件
- **相册**: 按日期分组浏览照片，支持缩略图和全屏查看
- **下载站**: 管理 NAS Download Station 任务（创建/暂停/恢复/删除）
- **系统监控**: 实时 CPU/内存/网络/磁盘使用率，存储卷和磁盘健康状态
- **虚拟机**: VMM 虚拟机管理和电源控制
- **自签名证书**: 原生支持自签名 HTTPS 证书

## 技术栈

- **Swift 5.9+** / **iOS 17+**
- **SwiftUI** + **@Observable** (Observation framework)
- **URLSession** + 自定义证书信任
- **UserDefaults** 持久化

## 项目结构

```
SynoLink/
├── SynoLinkApp.swift          # @main 入口
├── Info.plist                 # ATS + 本地网络权限
├── Models/                    # Codable 数据模型
│   ├── ServerConfig.swift     # 服务器/账号配置
│   └── DsmModels.swift        # DSM API 响应结构
├── Network/                   # 网络层
│   ├── DsmClient.swift        # 核心 HTTP 客户端 (actor)
│   ├── DsmApi+Auth.swift      # 认证 API
│   ├── DsmApi+FileStation.swift # 文件操作 API
│   ├── DsmApi+DownloadStation.swift # 下载站 API
│   ├── DsmApi+VMM.swift       # 虚拟机 API
│   └── DsmApi+System.swift    # 系统信息 API
├── Stores/                    # @Observable 状态管理
│   ├── AppStore.swift         # 全局应用状态
│   ├── DownloadStationStore.swift
│   ├── VmmStore.swift
│   └── SystemMonitorStore.swift
├── Views/                     # SwiftUI 视图
│   ├── Root/                  # 服务器列表/添加/登录
│   ├── Dashboard/             # 首页仪表盘
│   ├── Files/                 # 文件浏览器
│   ├── Album/                 # 相册
│   ├── Downloads/             # 下载站
│   ├── Monitor/               # 性能监控
│   ├── VMM/                   # 虚拟机
│   └── Settings/              # 设置
└── Utils/                     # 工具类
    ├── Format.swift           # 字节/速度格式化
    └── Extensions.swift       # SwiftUI 扩展
```

## 在 Xcode 中打开

1. 打开 Xcode → File → New → Project → iOS App
2. Product Name: `SynoLink`, Interface: SwiftUI, Language: Swift
3. 删除 Xcode 自动生成的文件
4. 将 `SynoLink/` 目录下所有文件拖入 Xcode 项目
5. 将 `Info.plist` 添加到项目根目录并配置到 Build Settings
6. Build & Run

## 架构说明

- **DsmClient** 使用 Swift `actor` 确保线程安全，所有 API 调用通过 `async/await`
- **@Observable** stores 自动追踪状态变化，无需手动 `@Published`
- 自签名证书通过 `URLSessionDelegate` 的 `urlSession(_:didReceive:completionHandler:)` 信任所有服务器证书
- 双 SID 策略：FileStation session + DownloadStation session 独立管理
