# Hearthwild 2D

Hearthwild 2D 是一个使用 **Godot 4.x + GDScript** 开发的原创俯视角像素生活冒险游戏。项目采用纯 2D 架构，并使用许可证明确的开源像素素材建立统一美术风格。

## 当前画面与玩法基础

- 640×360 像素基础视口，放大到 1280×720 时保持清晰像素边缘
- 16×16 开源地表图集按 2 倍显示，对应 32×32 逻辑地图格
- `96×64` 个逻辑地图格，对应 `3072×2048` 像素世界
- 西南农舍区、中央草地区、北部森林区和东部岩石区
- 两座可通行桥梁、连续河流边界和树木/岩石构成的自然地图边缘
- `CharacterBody2D` 玩家、八方向等速移动和四方向移动动画
- `Camera2D` 平滑跟随，鼠标滚轮进行 `0.75～1.50` 范围内的平滑缩放
- 统一 Y 排序：玩家可自然走到树冠和房屋屋檐前后
- 房屋墙体、树干、岩石底座、围栏和非桥梁河段具有实体碰撞
- 碰撞仅覆盖物体底座，树冠和屋顶不会成为整张图片大小的阻挡区域
- 左上角显示生命、体力和魔力；右上角显示完整世界小地图和玩家位置
- 20 格背包，前 5 格直接作为快捷栏
- 数字键 `1～5` 直接选择快捷栏，`Ctrl + 鼠标滚轮`循环切换快捷栏
- `Tab` 稳定打开或关闭背包与随身制作界面
- `Esc` 在背包打开时优先关闭背包
- 背包打开后单人世界暂停，关闭时只释放背包自己的暂停原因
- 树枝、碎石、工具、武器、种子、食物等首批物品数据
- 石斧、石镐、木剑和火把的随身制作界面
- 原子制作事务：材料不足或普通成品无处放置时不会错误扣除材料
- 左键按照当前快捷栏物品生成统一动作请求，为后续战斗、采集和种植提供稳定接口
- Python 仓库契约测试、Godot 无头玩法测试、资源导入和主场景烟雾测试
- 原创 SVG 仅在运行时图片损坏时作为最后降级资源

当前已完成**玩法基础、背包制作、大地图、相机、状态栏、小地图和世界实体碰撞阶段**。攻击伤害、闪避、敌人 AI、树木与矿石采集结果、实体掉落、种植成长、昼夜、存档和实际魔法能力仍未接入。

## 获取项目

运行时使用的开源图片已经直接打包进主仓库，**无需初始化 submodule**。GitHub ZIP、普通克隆和普通拉取都应显示真实像素美术：

```bash
git clone https://github.com/smple15981/mygames.git
cd mygames
```

然后：

1. 安装 Godot 4.3 或更新的 Godot 4.x。
2. 在 Godot 项目管理器中导入仓库根目录的 `project.godot`。
3. 运行主场景。

从旧版本更新后，建议关闭 Godot，删除项目根目录下的 `.godot` 缓存目录，再重新导入项目，确保旧场景和纹理不会留在导入缓存中。

## 操作

| 操作 | 键位 |
|---|---|
| 移动 | `WASD` 或方向键 |
| 使用当前快捷栏物品 | 鼠标左键或 `J` |
| 镜头缩放 | 鼠标滚轮 |
| 循环切换快捷栏 | `Ctrl + 鼠标滚轮` |
| 直接选择快捷栏 | 数字键 `1–5` |
| 打开或关闭背包与随身制作 | `Tab` |
| 背包打开时优先关闭 | `Esc` |
| 交互预留 | `E` |
| 闪避预留 | 空格或 `K` |

背包或随身制作界面打开时，玩家移动、物品使用和镜头缩放会被阻止，单人世界进入暂停。当前左键只生成动作请求，尚不会真正伤害敌人、砍树、挖矿或耕地。魔力已经拥有数据和 HUD 接口，但本阶段没有可释放的魔法技能。

## 世界与碰撞

世界尺寸由 `WorldLayoutConfig` 统一管理，地图、相机、小地图和坐标换算不再各自维护重复尺寸。

世界模型采用底座碰撞：

- 树木只阻挡树干和根部，玩家可走到树冠后方并被正确遮挡
- 房屋只在墙体和两侧产生碰撞，门口保持通行
- 岩石只使用贴合底部的碰撞范围
- 围栏按实际横向长度阻挡
- 河流在非桥梁区域形成连续实体边界
- 草丛、花朵和地面碎屑属于装饰，不会意外阻挡玩家

地图生成结束后会验证关键路线和安全出生点。未来读取存档时若玩家位置落入实体内部，碰撞注册器可搜索附近最近的安全位置，并在无法局部恢复时回退到农舍安全点。

## HUD 与小地图

- 左上角：生命、体力、魔力及区域文字
- 右上角：固定显示整个 `96×64` 世界的小地图
- 小地图绘制农舍区、草地区、森林区、岩石区、道路、河流、两座桥和农田
- 小地图显示玩家箭头、农舍和工坊等稳定标记
- 小地图直接根据世界数据绘制，不会用第二台摄像机重复渲染世界、灯光和粒子
- 底部中央：5 格快捷栏
- `Tab` 覆盖层：20 格背包与随身制作

## 开源美术

主美术来源是 **Ninja Adventure Asset Pack**。项目把实际需要的地表、村庄道具、玩家、小动物和阴影图片以紧凑运行时图集放在：

```text
assets/third_party/ninja-adventure/
```

同时保留：

- Kenney CC0 粒子图片，用于拾取物和局部灯光
- Tabler Icons MIT 图标，用于 HUD
- `assets/original/` 下的原创紧急降级素材和原创物品图标

准确来源、固定提交、图集修改方式、实际消费路径和许可证记录见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。

## 验证

```bash
python -m unittest discover -s tests -v
python tools/validate_project.py .
python -m compileall -q tools tests
godot --headless --path . --import
godot --headless --path . --script res://tests/godot/test_runner.gd
godot --headless --path . --quit-after 8
```

GitHub Actions 使用普通 checkout，不拉取 submodule，并执行 Python 测试、仓库验证、官方 Godot 资源导入、无头玩法测试和主场景启动检查。

自动测试覆盖：

- 世界尺寸和地图坐标换算
- 相机缩放上下限及世界边界
- Tab、Esc、滚轮、`Ctrl + 滚轮`与数字键输入路由
- 多暂停原因互不覆盖
- 三项玩家资源及 HUD 绑定
- 世界模型底座碰撞和唯一实例 ID
- 房屋门口、桥梁、关键路线和出生点可通行性
- 无效玩家位置恢复
- 小地图坐标、标记生命周期和最终 HUD 场景组合

## 目录

```text
assets/
├── original/       原创降级素材和物品图标
└── third_party/    直接进入仓库的开源运行时素材
data/
├── items/          物品 Resource 配置
├── recipes/        制作配方 Resource 配置
└── world/          世界尺寸、区域和模型碰撞配置
scenes/
├── bootstrap/      程序入口
├── player/         玩家、镜头和玩家资源组件
├── ui/             快捷栏、背包、三状态栏和小地图
└── world/          世界组合、灯光和环境节点
scripts/
├── actions/        统一动作请求与结果协议
├── assets/         开源素材加载与降级逻辑
├── core/           暂停所有权等全局协调组件
├── crafting/       配方与原子制作事务
├── input/          Tab、Esc、镜头和快捷栏输入路由
├── inventory/      20 格背包和快捷栏模型
├── items/          物品定义与目录
├── player/         移动、资源状态、镜头和物品使用分发
├── ui/             快捷栏、背包、状态栏和小地图逻辑
└── world/          地图生成、模型工厂、碰撞注册和环境效果
tools/              仓库验证工具
tests/              Python 与 Godot 无头自动测试
```

## 设计与实施文档

- 纯 2D 架构：`docs/superpowers/specs/2026-08-04-hearthwild-pure-2d-design.md`
- 开源美术升级：`docs/superpowers/specs/2026-08-04-open-art-visual-polish-design.md`
- 核心玩法垂直切片设计：`docs/superpowers/specs/2026-08-04-core-gameplay-vertical-slice-design.md`
- 世界、HUD、相机与碰撞设计：`docs/superpowers/specs/2026-08-04-world-ui-camera-collision-enhancement-design.md`
- 世界、HUD、相机与碰撞实施计划：`docs/superpowers/plans/2026-08-04-world-ui-camera-collision-enhancement.md`
- 五阶段核心玩法路线：`docs/superpowers/plans/2026-08-04-core-gameplay-vertical-slice-roadmap.md`

历史 HD-2D 文档仅作为决策记录，不代表当前实现方向。
