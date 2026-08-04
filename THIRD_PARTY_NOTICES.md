# Third-Party Notices

本文件记录已经进入仓库或通过固定 Git submodule 提供给项目的第三方内容。

## Godot Engine

- Project: Godot Engine
- Website: https://godotengine.org/
- License: MIT
- Usage: Game engine and runtime

## Ninja Adventure Asset Pack

- Authors: Pixel-Boy and AAA
- Official asset page: https://pixel-boy.itch.io/ninja-adventure-asset-pack
- Upstream repository: https://github.com/pixel-boy/NinjaAdventure
- Pinned upstream commit: `6ac78232d5aedcc85ce5f27d060ea92366f7c24a`
- Local submodule path: `vendor/ninja-adventure`
- Asset license: Creative Commons Zero (CC0)
- Usage: 16×16 floor tiles, village props, player sprite sheet, pig sprite sheet and character shadow

Consumed paths:

- `vendor/ninja-adventure/content/map/tileset_floor.png`
- `vendor/ninja-adventure/content/map/tileset_village_abandoned.png`
- `vendor/ninja-adventure/content/character/ninja_blue/sprite.png`
- `vendor/ninja-adventure/content/character/pig/sprite.png`
- `vendor/ninja-adventure/content/character/Shadow.png`

Only the art assets above are consumed by Hearthwild. Ninja Adventure gameplay scripts are not imported or executed.

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

1. 每个素材包放在独立目录或固定 submodule 中。
2. 必须保存许可证或来源记录。
3. `THIRD_PARTY_NOTICES.md` 必须写出项目实际消费的准确路径。
4. 不导入来源不明、禁止再分发或仅限个人使用的素材。
5. 商业发布前重新核验每项第三方内容。
