# Third-Party Notices

本文件记录已经直接进入仓库或由项目使用的第三方内容。

## Godot Engine

- Project: Godot Engine
- Website: https://godotengine.org/
- License: MIT
- Usage: Game engine and runtime

## Ninja Adventure Asset Pack

- Authors: Pixel-Boy and AAA
- Official asset page: https://pixel-boy.itch.io/ninja-adventure-asset-pack
- Upstream repository: https://github.com/pixel-boy/NinjaAdventure
- Pinned source commit: `6ac78232d5aedcc85ce5f27d060ea92366f7c24a`
- Asset license: Creative Commons Zero (CC0)
- Usage: floor tiles, village props, player sprite sheet, pig sprite sheet and character shadow

Bundled runtime files:

- `assets/third_party/ninja-adventure/tileset_floor.png`
  - Source: selected 16×16 cells from `content/map/tileset_floor.png`
  - Modification: packed into a compact seven-tile runtime atlas without resampling
- `assets/third_party/ninja-adventure/tileset_village_abandoned.png`
  - Source: selected regions from `content/map/tileset_village_abandoned.png`
  - Modification: packed into a compact runtime atlas without resampling; palette optimized
- `assets/third_party/ninja-adventure/ninja_blue.png`
  - Source: `content/character/ninja_blue/sprite.png`
- `assets/third_party/ninja-adventure/pig.png`
  - Source: `content/character/pig/pig.png`
- `assets/third_party/ninja-adventure/shadow.png`
  - Source: `content/character/Shadow.png`

这些运行时图片直接进入主仓库，因此 GitHub ZIP、普通 `git clone` 和普通 `git pull` 都包含实际美术。项目不执行 Ninja Adventure 的游戏逻辑代码。

## Kenney Starter Kit 3D Platformer — particle sprite

- Author: Kenney
- Upstream repository: https://github.com/KenneyNL/Starter-Kit-3D-Platformer
- Upstream reference inspected: `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0`
- License: Creative Commons Zero (CC0)
- Imported file: `assets/third_party/kenney/starter-kit-3d-platformer/particle.png`
- Usage: Pure 2D world pickup/glow marker
- Local license note: `assets/third_party/kenney/starter-kit-3d-platformer/LICENSE.md`

## Tabler Icons

- Project: Tabler Icons
- Author: Paweł Kuna and contributors
- Upstream repository: https://github.com/tabler/tabler-icons
- License: MIT
- Local license: `assets/third_party/tabler/tabler-icons/LICENSE`

Imported files:

- `assets/third_party/tabler/tabler-icons/heart.svg`
  - Upstream file: `icons/outline/heart.svg`
  - Usage: Health HUD icon
- `assets/third_party/tabler/tabler-icons/sword.svg`
  - Upstream file: `icons/outline/sword.svg`
  - Usage: Action HUD icon

## Asset intake rules

1. 每个素材包放在独立目录中。
2. 必须保存许可证、来源提交和修改说明。
3. `THIRD_PARTY_NOTICES.md` 必须写出项目实际消费的准确路径。
4. 不导入来源不明、禁止再分发或仅限个人使用的素材。
5. 商业发布前重新核验每项第三方内容。
