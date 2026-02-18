# 06. UI와 HUD

이 문서는 스킬바, HP/SP 게이지, 쿨타임 애니메이션의 구현을 설명합니다.

---

## 1. CanvasLayer란?

```
일반 노드 (Node3D):  3D 공간에 존재, 카메라에 따라 위치 변함
CanvasLayer:          화면 위에 고정된 2D 레이어 (HUD, UI)
```

CanvasLayer는 3D 카메라가 어디를 보든 항상 화면의 같은 위치에 표시됩니다. 게임의 HUD(HP바, 스킬바, 미니맵 등)에 사용합니다.

```
test_scene.tscn에서:
[node name="SkillBar" type="CanvasLayer" parent="."]
script = ExtResource("skill_bar_1")
```

---

## 2. UI 앵커(Anchor) 시스템

Godot의 Control 노드는 **앵커** 시스템으로 화면 내 위치를 결정합니다.

```
앵커 값 범위: 0.0 ~ 1.0

(0,0)─────────────(1,0)
│                    │
│    화면 영역       │
│                    │
(0,1)─────────────(1,1)
```

```gdscript
# 좌상단 고정
anchor_left = 0; anchor_top = 0

# 우하단 고정
anchor_left = 1; anchor_top = 1
anchor_right = 1; anchor_bottom = 1

# 전체 화면
set_anchors_preset(Control.PRESET_FULL_RECT)
```

**오프셋(offset)**: 앵커 위치에서의 픽셀 거리

```gdscript
# 우하단에서 MARGIN만큼 안쪽
hbox.anchor_left = 1.0
hbox.anchor_right = 1.0
hbox.anchor_top = 1.0
hbox.anchor_bottom = 1.0
hbox.offset_left = -(total_w + MARGIN)   # 왼쪽으로
hbox.offset_right = -MARGIN               # 오른쪽 여백
hbox.offset_top = -(SLOT_SIZE + MARGIN)   # 위쪽으로
hbox.offset_bottom = -MARGIN              # 아래쪽 여백
```

```
화면 우하단:
                        ┌──────────────────────┐
                        │  offset_left=-294     │
                        │  ┌───┬───┬───┬───┐   │ offset_right=-20
                        │  │ ⚡ │ 🔥 │   │   │   │
                        │  │ 1 │ 2 │ 3 │ 4 │   │
                        │  └───┴───┴───┴───┘   │
                        └──────────────────────┘
                                          offset_bottom=-20
```

---

## 3. 스킬바 구현 (skill_bar.gd)

### 상수 정의

```gdscript
const SLOT_SIZE := 64   # 슬롯 크기 (픽셀)
const GAP := 6          # 슬롯 간 간격
const MARGIN := 20      # 화면 가장자리 여백
const BORDER := 2       # 슬롯 테두리 두께
const ICONS := ["⚡", "🔥", "", ""]  # 각 슬롯의 아이콘
```

### UI 트리 구조 (코드에서 생성)

```gdscript
func _ready() -> void:
    _player = get_node("../Player")  # 플레이어 참조

    # 전체 화면을 덮는 루트 Control
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ★ 중요
    add_child(root)

    # 우하단에 배치되는 가로 컨테이너
    var hbox := HBoxContainer.new()
    # ...앵커/오프셋 설정...
    root.add_child(hbox)

    for i in 4:
        hbox.add_child(_create_slot(i))
```

**`mouse_filter = MOUSE_FILTER_IGNORE`가 중요한 이유:**

UI가 화면 전체를 덮으므로, 마우스 클릭이 UI에 먹힐 수 있습니다. `MOUSE_FILTER_IGNORE`를 설정하면 UI를 "뚫고" 게임 세계로 클릭이 전달됩니다.

```
MOUSE_FILTER_STOP:   이 컨트롤이 클릭 처리 (기본값)
MOUSE_FILTER_PASS:   처리하되 부모에게도 전달
MOUSE_FILTER_IGNORE: 완전히 무시 (투명한 것처럼)
```

### 슬롯 구조

```gdscript
func _create_slot(index: int) -> Control:
    var slot := Control.new()
    slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
```

각 슬롯은 다음 레이어로 구성됩니다:

```
┌─────────────────┐ ← Border (ColorRect, 회색)
│ ┌─────────────┐ │
│ │             │ │ ← Background (ColorRect, 어두운 파랑)
│ │     ⚡      │ │ ← Icon (Label, 이모지)
│ │  ████████  │ │ ← Cooldown Overlay (ColorRect, 반투명 검정)
│ │           1│ │ ← Key Number (Label, 작은 숫자)
│ └─────────────┘ │
└─────────────────┘
```

### 쿨타임 오버레이 애니메이션

```gdscript
func _process(_delta: float) -> void:
    if not _player:
        return

    var inner := SLOT_SIZE - BORDER * 2  # 내부 영역 크기 (60px)

    for i in 4:
        var cd: float = _player.skill_cooldowns[i]      # 남은 쿨타임
        var max_cd: float = _player.skill_max_cooldowns[i]  # 최대 쿨타임

        if max_cd > 0.0 and cd > 0.0:
            _overlays[i].visible = true
            var ratio := cd / max_cd          # 1.0 → 0.0으로 줄어듦
            _overlays[i].size.y = inner * ratio  # 높이를 비율에 맞게
        else:
            _overlays[i].visible = false
```

```
쿨타임 시작 (ratio=1.0):    중간 (ratio=0.5):     끝 (ratio=0):
┌──────────┐                ┌──────────┐           ┌──────────┐
│██████████│                │          │           │          │
│██████████│                │          │           │          │
│██████████│                │██████████│           │          │
│████⚡████│                │████⚡████│           │    ⚡    │
└──────────┘                └──────────┘           └──────────┘
 검은 오버레이가             절반 줄어듦             완전히 사라짐
 전체를 덮음                                        (사용 가능)
```

**오버레이의 position.y는 `BORDER`에 고정**: 위에서부터 줄어들기 때문에 위쪽 기준으로 고정되고 `size.y`만 변경합니다.

---

## 4. HP/SP 게이지 (좌하단)

### 게이지 생성 함수

```gdscript
func _create_gauge(parent: Control, y_pos: float, fill_color: Color,
        label_prefix: String) -> Array:
    # 배경 (어두운 색)
    var bg := ColorRect.new()
    bg.color = Color(0.15, 0.15, 0.2, 0.85)
    bg.anchor_left = 0    # 좌측
    bg.anchor_top = 1     # 하단
    bg.anchor_right = 0
    bg.anchor_bottom = 1
    bg.offset_left = MARGIN
    bg.offset_right = MARGIN + GAUGE_W  # 폭 200px
    bg.offset_top = y_pos
    bg.offset_bottom = y_pos + GAUGE_H  # 높이 22px
    parent.add_child(bg)

    # 채움 바 (색상, 배경 안에 2px 패딩)
    var fill := ColorRect.new()
    fill.color = fill_color
    fill.position = Vector2(2, 2)
    fill.size = Vector2(GAUGE_INNER_W, GAUGE_H - 4)
    bg.add_child(fill)

    # 텍스트 (중앙 정렬, 외곽선)
    var label := Label.new()
    label.text = label_prefix + ": 0 / 0"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 13)
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    label.add_theme_constant_override("outline_size", 3)
    bg.add_child(label)

    return [fill, label]  # 업데이트를 위해 반환
```

**`add_theme_*_override` 패턴:**

Godot의 Control 노드는 **테마(Theme)** 시스템으로 스타일링됩니다. 개별 노드의 스타일을 바꾸려면 `override` 함수를 사용합니다:

```gdscript
label.add_theme_font_size_override("font_size", 13)      # 폰트 크기
label.add_theme_color_override("font_color", Color.WHITE)  # 폰트 색상
label.add_theme_constant_override("outline_size", 3)       # 외곽선 두께
```

### 게이지 배치

```gdscript
# HP 게이지: 아래에서 위로 2번째 줄
var hp_result := _create_gauge(root,
    -(MARGIN + GAUGE_H * 2 + 4),  # y_pos (SP 위에)
    Color(0.2, 0.8, 0.2, 0.9),    # 녹색
    "HP")

# SP 게이지: 맨 아래 줄
var sp_result := _create_gauge(root,
    -(MARGIN + GAUGE_H),           # y_pos
    Color(0.2, 0.4, 0.9, 0.9),    # 파란색
    "SP")
```

```
화면 좌하단:
┌──────────────────┐
│ HP: 200 / 200    │ ← 녹색 채움
├──────────────────┤
│ SP: 100 / 100    │ ← 파란색 채움
└──────────────────┘
   20px 여백 ↕
```

### 실시간 업데이트

```gdscript
func _process(_delta: float) -> void:
    # ...스킬바 쿨타임 업데이트...

    # HP 게이지
    var hp_ratio := clampf(_player.current_hp / _player.max_hp, 0.0, 1.0)
    _hp_gauge_fill.size.x = GAUGE_INNER_W * hp_ratio  # 채움 바 폭 조절
    _hp_gauge_label.text = "HP: %d / %d" % [
        ceili(maxf(_player.current_hp, 0.0)),
        int(_player.max_hp)
    ]

    # SP 게이지 (같은 방식)
    var sp_ratio := clampf(_player.current_sp / _player.max_sp, 0.0, 1.0)
    _sp_gauge_fill.size.x = GAUGE_INNER_W * sp_ratio
    _sp_gauge_label.text = "SP: %d / %d" % [...]
```

**`%` 포맷 연산자:**
```gdscript
"%d / %d" % [150, 200]  →  "150 / 200"
# %d = 정수, %f = 실수, %s = 문자열
```

---

## 5. skill_bar.gd와 player.gd의 연결

skill_bar는 플레이어의 데이터를 직접 읽습니다:

```gdscript
# skill_bar.gd
_player = get_node("../Player")

# 매 프레임 플레이어 데이터 읽기
_player.skill_cooldowns[i]
_player.skill_max_cooldowns[i]
_player.current_hp
_player.max_hp
_player.current_sp
_player.max_sp
```

**이것은 "폴링(polling)" 패턴입니다:**
- 매 프레임 값을 확인하는 방식
- 장점: 구현이 단순함
- 단점: 변경이 없어도 매 프레임 실행됨

**대안: 시그널(signal) 패턴:**
```gdscript
# player.gd에서
signal hp_changed(current, max)

func take_damage(amount):
    current_hp -= amount
    hp_changed.emit(current_hp, max_hp)

# skill_bar.gd에서
_player.hp_changed.connect(_on_hp_changed)
```

이 프로젝트에서는 값이 매 프레임 바뀔 수 있고(쿨타임), 코드가 단순해지므로 폴링 방식을 사용합니다.

---

## 6. 탄약 표시 (skill_bar.gd)

권총을 장착했을 때만 스킬바 위에 탄약 수를 표시합니다:

### 생성 (우측 하단, 스킬바 위)

```gdscript
_ammo_label = Label.new()
_ammo_label.anchor_left = 1.0
_ammo_label.anchor_right = 1.0
_ammo_label.anchor_top = 1.0
_ammo_label.anchor_bottom = 1.0
_ammo_label.offset_top = -(SLOT_SIZE + MARGIN + 28)   # 스킬바 위에 배치
_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
_ammo_label.visible = false   # 기본은 숨김
```

### 업데이트 (조건부 표시 + 색상 변경)

```gdscript
func _process(_delta: float) -> void:
    # ...스킬바, HP/SP 업데이트...

    # 탄약 표시: 권총 장착 시에만
    if _player.equipped_right_hand == "pistol":
        _ammo_label.visible = true
        _ammo_label.text = "AMMO: %d" % _player.pistol_ammo
        if _player.pistol_ammo <= 0:
            _ammo_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # 빨강
        else:
            _ammo_label.add_theme_color_override("font_color", Color.WHITE)
    else:
        _ammo_label.visible = false
```

```
권총 장착 시:                       미장착 시:
                 AMMO: 5            (표시 안 됨)
  ┌───┬───┬───┬───┐
  │ ⚡ │ 🔥 │ 💨 │   │
  └───┴───┴───┴───┘
```

---

## 7. 인벤토리 UI (inventory_ui.gd)

### CanvasLayer 기반 오버레이

인벤토리도 CanvasLayer이므로 3D 세계 위에 고정 표시됩니다.

```gdscript
extends CanvasLayer

func _ready() -> void:
    _player = get_node("../Player")
```

### I키 토글

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_I:
        _toggle_inventory()

func _toggle_inventory() -> void:
    if _panel:
        _close_inventory()
    else:
        _open_inventory()
    _player.inventory_open = _panel != null   # 플레이어에게 상태 전달
```

**`inventory_open` 플래그의 역할**: player.gd에서 인벤토리가 열려있으면 이동/공격을 차단합니다. UI와 게임 로직의 상태 동기화입니다.

### 슬롯 인터랙션

```gdscript
# 각 슬롯에 gui_input 시그널 연결
slot.gui_input.connect(_on_slot_input.bind(i))

func _on_slot_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed:
        match event.button_index:
            MOUSE_BUTTON_LEFT:  _equip_item(index)    # 좌클릭 = 장착
            MOUSE_BUTTON_RIGHT: _trash_item(index)    # 우클릭 = 버리기
```

**`.bind(i)` 패턴**: 시그널 콜백에 추가 인자를 전달합니다. 8개 슬롯이 모두 같은 함수를 사용하되, `index`로 어떤 슬롯인지 구분합니다.

### 장착 로직

```gdscript
func _equip_item(index: int) -> void:
    var item_id := _player.inventory[index]
    if item_id == "":
        return

    # 기존 장착 아이템이 있으면 인벤토리로 반환
    if _player.equipped_right_hand != "":
        var old := _player.unequip_right_hand()
        _player.inventory[index] = old       # 교체
    else:
        _player.inventory[index] = ""        # 빈 칸으로

    _player.equip_to_right_hand(item_id)     # 새 아이템 장착
    _refresh_slots()                          # UI 갱신
```

---

## 8. 볼륨 조절 (skill_bar.gd)

화면 우측 상단에 마스터 볼륨 슬라이더:

```gdscript
func _create_volume_control(parent: Control) -> void:
    # HBoxContainer: [VOL 라벨] [슬라이더] [100% 라벨]
    _volume_slider = HSlider.new()
    _volume_slider.min_value = 0.0
    _volume_slider.max_value = 1.0
    _volume_slider.step = 0.05
    _volume_slider.value = 1.0
    _volume_slider.value_changed.connect(_on_volume_changed)

func _on_volume_changed(value: float) -> void:
    if value <= 0.0:
        AudioServer.set_bus_mute(0, true)    # 음소거
    else:
        AudioServer.set_bus_mute(0, false)
        AudioServer.set_bus_volume_db(0, linear_to_db(value))  # 선형→dB 변환
    _volume_label.text = "%d%%" % int(value * 100)
```

**AudioServer API:**
- `set_bus_volume_db(bus_idx, db)`: 버스 볼륨 설정 (dB 단위)
- `set_bus_mute(bus_idx, mute)`: 버스 음소거 토글
- `linear_to_db(linear)`: 0.0~1.0 선형 값을 dB로 변환 (0.5 → -6dB)
- 버스 인덱스 0 = Master 버스 (모든 사운드에 영향)

**`HSlider`**: Godot의 수평 슬라이더 위젯. `value_changed` 시그널로 값 변경을 실시간 감지합니다.

---

## 9. Game Over 화면 (skill_bar.gd)

플레이어 HP가 0이 되면 나타나는 오버레이:

```gdscript
func show_game_over() -> void:
    # 어두운 반투명 배경 (0 → 0.6 알파 페이드)
    var overlay := ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.0)
    fade_tween.tween_property(overlay, "color:a", 0.6, 1.0)

    # "GAME OVER" 텍스트 (큰 빨간 글씨)
    title.text = "GAME OVER"
    title.add_theme_font_size_override("font_size", 64)
    title.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1))

    # Restart 버튼
    btn.pressed.connect(_restart_game)

    # 순차 애니메이션 (fade → title → subtitle → button)
    tween.tween_property(title, "modulate:a", 1.0, 0.5).set_delay(0.3)
    tween.tween_property(subtitle, "modulate:a", 1.0, 0.5)
    tween.tween_property(btn, "modulate:a", 1.0, 0.3)

func _restart_game() -> void:
    get_tree().reload_current_scene()   # 씬 전체 다시 로드
```

**`reload_current_scene()`**: 현재 씬을 완전히 삭제하고 다시 로드합니다. 모든 변수가 초기화되므로 간단한 리스타트에 적합합니다.

---

## 다음 단계

[07. 이펙트와 렌더링](07-effects-and-rendering.md)에서 머티리얼, 파티클, 조명을 자세히 살펴봅니다.
