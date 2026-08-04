# Hearthwild 2D 开源美术升级规格

日期：2026-08-04  
状态：已根据用户“提高画质并继续开发”的要求确认  
目标引擎：Godot 4.3+

## 1. 目标

把当前由简单颜色块和原创占位 SVG 组成的纯 2D 原型，升级成风格统一、可以展示的俯视像素场景。此次不扩张战斗、背包、种植逻辑或联机范围，只提升现有移动原型的画面质量和美术管线。

## 2. 美术来源

主素材采用 Pixel-Boy 与 AAA 的 **Ninja Adventure Asset Pack**。官方 itch.io 页面声明素材使用 Creative Commons Zero（CC0），并提供 Godot 4 项目。仓库通过 Git submodule 固定到上游提交 `6ac78232d5aedcc85ce5f27d060ea92366f7c24a`。

- 上游仓库：`pixel-boy/NinjaAdventure`
- 本地路径：`vendor/ninja-adventure`
- 只消费其中的 2D 美术资源，不复用其游戏逻辑代码。
- 继续保留现有 Kenney CC0 粒子和 Tabler MIT 图标。
- 原创 SVG 只作为子模块缺失时的降级占位资源。

## 3. 视觉方向

- 原始素材以 16×16 像素网格制作，在游戏中统一放大 2 倍，对应 32×32 逻辑格。
- 基础视口继续使用 640×360，保持 nearest-neighbor 采样。
- 地面使用 Ninja Adventure 的 `tileset_floor.png`，道路、泥土、草地和石地区域来自同一图集。
- 房屋、树木、岩石和围栏使用 `tileset_village_abandoned.png` 的区域切片。
- 玩家使用 `content/character/ninja_blue/sprite.png`，按上游定义的 4 列方向 × 7 行动作布局播放。
- 动物原型使用 `content/character/pig/pig.png`，按上游2帧横向布局播放，不在本阶段加入 AI。
- 加入像素水面动画、柔和全局色调、房屋暖光和漂浮粒子。

## 4. 技术结构

### 4.1 OpenAssetLibrary

`OpenAssetLibrary` 负责检查 submodule 文件并加载纹理。因为上游目录自身包含 `project.godot`，Godot 会把它视为嵌套项目而跳过常规导入；因此 `res://vendor/` 下的 PNG 使用 `Image.load()` 解码，再创建 `ImageTexture`。本地 SVG 与其他仓库内素材继续通过 `ResourceLoader` 加载。

所有纹理进入缓存。子模块缺失、文件解码失败或路径不存在时，加载器输出一次明确警告并使用原创降级资源。

### 4.2 PrototypeWorld

`PrototypeWorld` 负责：

1. 从开源地表图集创建运行时 `TileSetAtlasSource`。
2. 以 40×24 格生成草地、道路、农田、水域和石地区域。
3. 从村庄图集切片生成房屋、树木、岩石、围栏和装饰物。
4. 创建与画面对应的简化碰撞体。
5. 在缺少子模块时自动退回颜色瓦片和 SVG 道具。

### 4.3 PlayerController

玩家视觉从单帧 `AnimatedSprite2D` 改为 `Sprite2D` 图集播放：

- 方向列：Down=0、Up=1、Left=2、Right=3。
- 静止时使用第 0 行。
- 移动时循环第 0～3 行。
- 保留原有八方向移动和 `Camera2D`。

### 4.4 环境表现

- `WaterSurface` 使用 `_draw()` 生成像素水面和移动高光，不依赖额外贴图。
- `CanvasModulate` 统一场景色调。
- `PointLight2D` 为房屋与掉落物提供暖色/冷色局部光。
- HUD 使用紧凑像素面板、生命条、区域名和操作提示。

## 5. 错误处理

- 子模块未初始化：打印一次清晰警告并使用原创占位资源。
- PNG 解码失败：跳过对应开源纹理并尝试降级资源。
- 图集区域超出纹理范围：运行时跳过该切片并输出警告。
- CI 使用 `actions/checkout` 的 `submodules: recursive`，保证验证包含开源素材。
- CI 使用官方 Godot 进行无头导入和主场景短时启动；出现 `SCRIPT ERROR` 或 `ERROR:` 时直接失败。

## 6. 测试与验收

自动检查：

- `.gitmodules` 固定正确仓库路径。
- CI 会递归拉取 submodule。
- 运行时代码不包含 3D 节点。
- 玩家使用 `Sprite2D`、4×7 图集和 Camera2D。
- 世界脚本声明开源地表、村庄、角色和阴影路径。
- 子模块缺失时仍存在降级资源。
- 所有第三方来源在 `THIRD_PARTY_NOTICES.md` 登记。
- Godot 可以解析全部脚本并短时启动主场景。

人工验收：

- 地面不再是纯色块，而是统一像素图集。
- 玩家至少有四方向移动动画。
- 房屋、树木和岩石在 Y 排序中前后关系正确。
- 水面、灯光和粒子不会影响移动可读性。
- 640×360 放大到 1280×720 时像素边缘清晰。

## 7. 本阶段不做

- 完整战斗连招和伤害系统。
- 农作物生长、背包、制作和存档。
- 昼夜循环与动态天气。
- 大地图编辑器或程序生成。
- 联机。
