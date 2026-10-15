my_flutter_project/
├── android/                # Android原生工程（gradle、Manifest、权限配置）
├── ios/                    # iOS原生工程（Info.plist、Podfile）
├── linux/                  # Linux桌面端
├── macos/                  # macOS桌面端
├── windows/                # Windows桌面端
├── web/                    # Web平台产物目录
├── assets/                 # 静态资源【需要手动创建】
│   ├── images/             # 图片 png/jpg/webp
│   ├── icons/              # icon图标
│   ├── fonts/              # 字体文件
│   └── json/               # 本地json配置
├── lib/                    # Dart主代码目录（核心）
│   ├── main.dart           # 入口文件，runApp起点
│   ├── app/                # 全局App配置【企业常用，手动建】
│   │   ├── app.dart        # MyApp 根组件
│   │   ├── routes.dart     # 路由表、路由管理
│   │   └── theme.dart      # 全局主题、颜色、字体样式
│   ├── features/          # 业务模块（推荐模块化，flutter最新推荐）
│   │   ├── home/           # 首页模块
│   │   │   ├── home_page.dart
│   │   │   ├── home_controller.dart
│   │   │   ├── home_repository.dart
│   │   │   └── widgets/    # 本模块私有小组件
│   │   └── login/          # 登录模块
│   ├── widgets/            # 全局公共组件（跨业务通用）
│   │   ├── common_button.dart
│   │   ├── empty_view.dart
│   │   └── loading.dart
│   ├── core/               # 底层核心工具
│   │   ├── network/         # http封装、dio、拦截器
│   │   ├── storage/        # 本地存储 shared_preferences / hive
│   │   ├── constants/      # 常量：颜色、接口地址、正则
│   │   ├── utils/          # 工具类：日期、格式化、校验
│   │   └── exceptions/     # 异常统一处理
│   └── models/             # 数据模型（实体类、DTO）
├── test/                   # 单元测试
├── integration_test/       # 集成测试
├── pubspec.yaml            # 项目配置、依赖、assets、版本号
├── pubspec.lock            # 依赖锁定文件，不要手动改
├── README.md
└── .gitignore
