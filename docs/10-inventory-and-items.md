# 10. 인벤토리와 아이템 시스템

이 문서는 인벤토리 UI, 아이템 픽업, 장착, 탄약 시스템, 아이템 리스폰 로직을 설명합니다.

---

## 1. 전체 구조

```
아이템 관련 파일:
├── pickup_item.gd        # 바닥에 놓인 픽업 아이템 (클릭해서 줍기)
├── chicken_pickup.gd     # 치킨 회복 아이템 (밟으면 즉시 회복)
├── ammo_pickup.gd        # 탄약 픽업 (밟으면 자동 획득)
├── inventory_ui.gd       # 인벤토리 UI (I키로 열기)
├── pistol_material.gd    # 권총 머티리얼 (2톤 금속 질감)
└── test_scene.gd         # 아이템 스폰/리스폰 관리
```

### 아이템 종류

| 아이템 | 획득 방법 | 인벤토리 | 효과 |
|--------|-----------|----------|------|
| 권총 | 클릭해서 줍기 | O (장착 가능) | 우클릭 사격 |
| 치킨 | 밟으면 자동 | X (즉시 사용) | HP +50 회복 |
| 탄약 | 밟으면 자동 | X (즉시 사용) | 탄약 +4발 |

---

## 2. 인벤토리 시스템 (player.gd)

### 데이터 구조

```gdscript
# 8칸 인벤토리 (빈 칸은 빈 문자열)
var inventory: Array[String] = ["", "", "", "", "", "", "", ""]

# 현재 오른손에 장착한 아이템
var equipped_right_hand: String = ""
```

**왜 `Array[String]`인가?**

아이템 종류가 적으므로 문자열 ID로 충분합니다. 프로젝트가 커지면 `Resource` 기반 아이템 데이터베이스로 확장할 수 있습니다.

### 아이템 줍기

```gdscript
func _try_pickup(pickup: Node) -> void:
    for i in inventory.size():
        if inventory[i] == "":       # 빈 칸 찾기
            inventory[i] = pickup.item_id
            if pickup.item_id == "pistol":
                pistol_ammo = mini(pistol_ammo + 8, PISTOL_MAX_AMMO)
            pickup.collect()         # 월드에서 아이템 제거
            return
    # 빈 칸이 없으면 아무것도 안 함 (인벤토리 가득 참)
```

**`mini(a, b)` 함수**: 정수 최소값. `pistol_ammo + 8`과 `PISTOL_MAX_AMMO(8)` 중 작은 값을 사용하여 최대 탄약을 초과하지 않게 합니다.

### 장착과 해제

```gdscript
func equip_to_right_hand(item_id: String) -> void:
    _clear_right_hand_model()      # 기존 장착 모델 제거
    equipped_right_hand = item_id
    if item_id == "pistol":
        _attach_pistol_to_hand()   # 3D 모델을 캐릭터 손에 부착

func unequip_right_hand() -> String:
    var item := equipped_right_hand
    equipped_right_hand = ""
    _clear_right_hand_model()      # 3D 모델 제거
    return item                     # 인벤토리로 되돌릴 아이템 ID 반환
```

### 권총 손에 부착

```gdscript
func _attach_pistol_to_hand() -> void:
    var model := get_node_or_null("CharacterModel")
    if not model:
        return
    _equipped_model = _pistol_scene.instantiate()
    _equipped_model.scale = Vector3(0.5, 0.5, 0.5)
    _equipped_model.position = Vector3(-0.5, 0.4, 0.15)   # 오른손 위치
    _equipped_model.rotation_degrees = Vector3(0, 90, 0)    # 총구가 앞을 향하게
    model.add_child(_equipped_model)
    PistolMaterial.apply(_equipped_model)                   # 머티리얼 적용
```

**왜 `CharacterModel`의 자식으로 추가하는가?**

CharacterModel은 캐릭터의 3D 모델 노드입니다. 자식으로 추가하면 캐릭터가 회전할 때 총도 함께 회전합니다. 만약 Player(CharacterBody3D)의 자식으로 추가하면 캐릭터가 방향을 바꿔도 총이 같은 방향을 바라봅니다.

```
Player (CharacterBody3D)     ← 물리 처리, 회전하지 않음
├── CharacterModel (Node3D)  ← 시각적 모델, rotation.y로 방향 전환
│   ├── Skeleton3D           ← 본(bone) 애니메이션
│   └── _equipped_model      ← 장착된 권총 (CharacterModel과 함께 회전)
└── CollisionShape3D
```

### 보유 여부 확인

```gdscript
func has_pistol() -> bool:
    if equipped_right_hand == "pistol":
        return true
    for item in inventory:
        if item == "pistol":
            return true
    return false
```

이 함수는 리스폰 시스템에서 사용됩니다. 플레이어가 권총을 가지고 있으면 탄약만 리스폰하고, 없으면 권총을 리스폰합니다.

---

## 3. 인벤토리 UI (inventory_ui.gd)

### I키로 열기/닫기

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_I:
        _toggle_inventory()
```

### 슬롯 클릭 인터랙션

각 슬롯은 `gui_input` 시그널로 클릭을 감지합니다:

```gdscript
# Left-click = 장착/해제
# Right-click = 버리기 (trash)
slot.gui_input.connect(_on_slot_input.bind(i))

func _on_slot_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _equip_item(index)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _trash_item(index)
```

### UI 레이아웃

```
┌─────────────────────────────────────┐
│           INVENTORY                  │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐│
│  │      │ │      │ │      │ │      ││
│  │  1   │ │  2   │ │  3   │ │  4   ││
│  └──────┘ └──────┘ └──────┘ └──────┘│
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐│
│  │      │ │      │ │      │ │      ││
│  │  5   │ │  6   │ │  7   │ │  8   ││
│  └──────┘ └──────┘ └──────┘ └──────┘│
│                                      │
│  Equipped: [pistol icon]             │
│                                      │
│  Left-click = Equip/Unequip          │
│  Right-click = Trash                 │
└─────────────────────────────────────┘
```

**`inventory_open` 플래그**: 인벤토리가 열려 있으면 `player.gd`의 `_unhandled_input`에서 입력을 무시합니다:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if is_dead or inventory_open:   # ← 인벤토리 열림 상태면 이동/공격 차단
        return
```

---

## 4. 바닥 아이템: 권총 픽업 (pickup_item.gd)

### 구조: Area3D + StaticBody3D

```gdscript
extends Area3D  # 기본은 Area3D (overlap 감지 가능)

func _ready() -> void:
    add_to_group("pickup")          # 그룹으로 개수 카운팅
    collision_layer = 0             # 자체 충돌 없음
    collision_mask = 0

    # StaticBody3D: 레이캐스트 클릭 감지용
    var click_body := StaticBody3D.new()
    click_body.add_to_group("pickup_body")
    click_body.set_meta("pickup_owner", self)   # ★ 메타데이터로 소유자 연결
    var click_col := CollisionShape3D.new()
    click_col.shape = BoxShape3D.new()
    click_body.add_child(click_col)
    add_child(click_body)
```

**왜 Area3D + StaticBody3D 두 개인가?**

- **Area3D**: 그룹화와 비주얼 관리를 위한 컨테이너
- **StaticBody3D**: 마우스 클릭 레이캐스트에 잡히려면 물리 바디가 필요

**`set_meta("pickup_owner", self)` 패턴**: 플레이어가 StaticBody3D를 클릭하면, 그 메타데이터에서 실제 픽업 아이템(Area3D)을 찾습니다:

```gdscript
# player.gd의 _handle_click에서
elif result.collider.is_in_group("pickup_body"):
    var pickup = result.collider.get_meta("pickup_owner", null)
    if pickup and is_instance_valid(pickup):
        _try_pickup(pickup)
```

### 물에 떠다니는 효과 (Bobbing)

```gdscript
const BOB_SPEED := 2.0    # 진동 주파수
const BOB_HEIGHT := 0.15  # 진동 높이

var _base_y: float
var _time: float = 0.0

func _process(delta: float) -> void:
    _time += delta
    position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT  # ← 사인파 위아래
    _model.rotation.y += delta * 1.5                             # ← 천천히 회전
```

```
시간 →
       ╱╲        ╱╲
_base_y  ╲      ╱  ╲
           ╲╱          ╲╱

sin 함수로 부드러운 위아래 움직임
```

---

## 5. 치킨 회복 아이템 (chicken_pickup.gd)

### Walk-over 픽업 (밟으면 자동)

권총과 달리 치킨은 **밟으면 즉시 효과**가 적용됩니다:

```gdscript
extends Area3D

func _ready() -> void:
    add_to_group("chicken_pickup")
    collision_layer = 4   # 레이어 3 (비트 4)
    collision_mask = 1    # 레이어 1만 감지 (플레이어)

    # body_entered: 물리 바디가 영역에 들어올 때 자동 호출
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player") and body.has_method("heal_hp"):
        body.heal_hp(HEAL_AMOUNT)   # HP 50 회복
        # 효과음 (씬 루트에 추가하여 치킨 삭제 후에도 재생)
        var sfx := AudioStreamPlayer.new()
        sfx.stream = preload("res://sounds/gulp.wav")
        get_tree().current_scene.add_child(sfx)
        sfx.play()
        sfx.finished.connect(sfx.queue_free)
        queue_free()  # 치킨 제거
```

**Area3D vs StaticBody3D 차이:**

```
StaticBody3D: 물리적으로 단단함. 다른 물체가 통과 못 함
              레이캐스트에 잡힘 (마우스 클릭 감지 가능)

Area3D:       물리적으로 투과됨. 물체가 자유롭게 통과
              body_entered/exited 시그널로 overlap 감지
              레이캐스트에 안 잡힘 (직접 클릭 불가)
```

치킨은 밟으면 자동이므로 Area3D가 적합합니다.

### 절차적 3D 모델 (치킨 다리)

에디터나 외부 모델 없이 코드로 3D 모양을 만듭니다:

```gdscript
# 고기 부분 (황금색 구)
var meat := MeshInstance3D.new()
var meat_mesh := SphereMesh.new()
meat_mesh.radius = 0.25
meat_mesh.height = 0.4
meat.mesh = meat_mesh
var meat_mat := StandardMaterial3D.new()
meat_mat.albedo_color = Color(0.85, 0.6, 0.2)  # 황금색
meat.material_override = meat_mat
meat.position = Vector3(0, 0.35, 0)

# 뼈 부분 (흰색 실린더)
var bone := MeshInstance3D.new()
var bone_mesh := CylinderMesh.new()
bone_mesh.top_radius = 0.04
bone_mesh.bottom_radius = 0.05
bone_mesh.height = 0.3
bone.position = Vector3(0, 0.1, 0)

# 뼈 끝 동그란 부분
var knob := MeshInstance3D.new()
var knob_mesh := SphereMesh.new()
knob_mesh.radius = 0.06
```

```
결과물:
    ⬤  ← 고기 (황금색 구)
    │   ← 뼈 (흰색 실린더)
    ◦   ← 뼈 끝 (작은 구)
```

---

## 6. 탄약 픽업 (ammo_pickup.gd)

### 치킨과 같은 walk-over 패턴

```gdscript
func _on_body_entered(body: Node3D) -> void:
    if body.is_in_group("player") and body.has_method("add_ammo"):
        if not body.has_pistol():   # 권총이 없으면 무시
            return
        if body.pistol_ammo >= body.PISTOL_MAX_AMMO:  # 이미 최대면 무시
            return
        body.add_ammo(AMMO_AMOUNT)  # 4발 추가
        queue_free()
```

### 탄약 추가 (player.gd)

```gdscript
func add_ammo(amount: int) -> void:
    if not has_pistol():
        return
    var old_ammo := pistol_ammo
    pistol_ammo = mini(pistol_ammo + amount, PISTOL_MAX_AMMO)  # 최대 8발
    var added := pistol_ammo - old_ammo
    if added > 0:
        _spawn_heal_number_custom("+%d AMMO" % added, Color(1.0, 0.85, 0.2))
```

### 3D 모델 (황동 탄환)

```
 △  △  ← 탄두 (어두운 원뿔)
 ║  ║  ← 탄피 (황동색 실린더)
  x4   ← Label3D (수량 표시)
```

---

## 7. 권총 머티리얼 시스템 (pistol_material.gd)

Meshy AI로 생성한 권총 모델은 텍스처가 없으므로 코드에서 머티리얼을 적용합니다:

```gdscript
class_name PistolMaterial  # ← 전역 클래스 이름. 어디서든 PistolMaterial.apply() 사용 가능

static func apply(node: Node) -> void:
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(node, meshes)
    for i in meshes.size():
        if i == 0:
            meshes[i].material_override = _barrel_material()   # 총신: 어두운 금속
        else:
            meshes[i].material_override = _grip_material()     # 그립: 갈색
```

**`class_name` 사용 이유:**

```gdscript
# class_name 없이: 스크립트를 직접 로드해야 함
var PistolMat = preload("res://pistol_material.gd")
PistolMat.apply(model)

# class_name 사용: 전역으로 접근 가능
PistolMaterial.apply(model)   # ← 깔끔
```

### 2톤 머티리얼

```gdscript
static func _barrel_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.15, 0.18)  # 거의 검정
    mat.metallic = 0.9                            # 높은 금속성
    mat.roughness = 0.25                          # 낮은 거칠기 → 반사 많음
    return mat

static func _grip_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.3, 0.2, 0.12)    # 갈색
    mat.metallic = 0.1                            # 비금속
    mat.roughness = 0.75                          # 높은 거칠기 → 매트
    return mat
```

**metallic + roughness 조합:**

```
roughness 낮음 + metallic 높음 = 반짝이는 금속 (총신)
roughness 높음 + metallic 낮음 = 매트한 표면 (나무 그립)
```

---

## 8. 아이템 리스폰 시스템 (test_scene.gd)

### 핵심 로직: 플레이어 상태에 따른 조건부 리스폰

```gdscript
func _process(delta: float) -> void:
    # 치킨: 항상 리스폰 (15초마다, 최대 3개)
    _chicken_timer += delta
    if _chicken_timer >= CHICKEN_RESPAWN_TIME:
        _chicken_timer = 0.0
        if get_tree().get_nodes_in_group("chicken_pickup").size() < MAX_CHICKENS:
            _spawn_chicken()

    # 권총/탄약: 플레이어 상태에 따라 분기
    if _player.has_pistol():
        # ★ 권총 보유 중 → 탄약만 리스폰
        _ammo_timer += delta
        _pistol_timer = 0.0          # 권총 타이머 리셋
        if _ammo_timer >= AMMO_RESPAWN_TIME:
            _ammo_timer = 0.0
            if get_tree().get_nodes_in_group("ammo_pickup").size() < MAX_AMMO_PICKUPS:
                _spawn_ammo()
    else:
        # ★ 권총 없음 (버림) → 권총만 리스폰
        _pistol_timer += delta
        _ammo_timer = 0.0            # 탄약 타이머 리셋
        if _pistol_timer >= PISTOL_RESPAWN_TIME:
            _pistol_timer = 0.0
            if get_tree().get_nodes_in_group("pickup").size() < 1:
                _spawn_pistol()
```

**리스폰 규칙 요약:**

```
플레이어가 권총 있음 (인벤토리 또는 장착):
  → 탄약 리스폰 (12초마다, 맵에 최대 2개)
  → 권총 리스폰 안 함

플레이어가 권총 없음 (버렸을 때):
  → 권총 리스폰 (30초마다, 맵에 최대 1개)
  → 탄약 리스폰 안 함 (총이 없으니 의미 없음)

치킨: 항상 리스폰 (15초마다, 맵에 최대 3개)
```

### 그룹 기반 카운팅

```gdscript
get_tree().get_nodes_in_group("chicken_pickup").size()
```

그룹은 런타임에 현재 씬 트리에 있는 노드만 카운트합니다. `queue_free()`로 제거된 아이템은 자동으로 그룹에서 빠집니다.

---

## 다음 단계

[11. 적 AI 시스템](11-enemy-ai.md)에서 적의 행동 패턴과 상태 머신을 살펴봅니다.
