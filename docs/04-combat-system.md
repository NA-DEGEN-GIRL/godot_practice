# 04. 전투 시스템

이 문서는 공격, 데미지, 크리티컬 히트, HP 바, 데미지 숫자, 적 사망/리스폰을 설명합니다.

---

## 1. 근접 공격 흐름

### 전체 흐름

```
1. 적 클릭 → _attack_target 설정
2. 매 물리 프레임: 적에게 접근
3. 사정거리 안에 도달 → 공격 실행
4. 쿨타임 대기 → 다음 공격 가능 (하지만 한번 때리면 타겟 해제)
```

### 코드 분석 (player.gd: _physics_process)

```gdscript
# 공격 대상이 있을 때
if _attack_target:
    # 대상이 유효한지 체크 (죽었거나 사라졌으면 취소)
    if not is_instance_valid(_attack_target) or not _attack_target.visible:
        _attack_target = null
    else:
        var dist := global_position.distance_to(_attack_target.global_position)

        if dist <= attack_range:  # 사정거리 안에 들어왔으면
            _moving = false
            velocity = Vector3.ZERO

            if _attack_timer <= 0.0:  # 쿨타임 끝났으면
                # ★ 크리티컬 판정
                var is_crit := randf() < crit_chance
                var dmg := attack_damage * (crit_multiplier if is_crit else 1.0)

                _attack_target.take_damage(dmg, is_crit)
                _attack_timer = attack_cooldown  # 쿨타임 시작
                _attack_target = null             # 한 번만 때리기
            return
        else:
            # 아직 멀면 계속 접근
            _target = _attack_target.global_position
```

### 주요 수치 (@export)

```gdscript
@export var attack_range: float = 2.0      # 공격 사정거리
@export var attack_damage: float = 25.0    # 기본 공격력
@export var attack_cooldown: float = 0.5   # 공격 쿨타임 (초)
@export var crit_chance: float = 0.2       # 크리티컬 확률 (20%)
@export var crit_multiplier: float = 2.0   # 크리티컬 배율 (2배)
```

`@export`를 사용하면 Godot 에디터의 인스펙터 패널에서 값을 조절할 수 있습니다. 게임을 다시 실행하지 않고도 밸런스 조정이 가능합니다.

---

## 2. 크리티컬 히트

### 판정 로직

```gdscript
var is_crit := randf() < crit_chance  # randf()는 0.0~1.0 랜덤
# crit_chance = 0.2이면 20% 확률로 true

var dmg := attack_damage * (crit_multiplier if is_crit else 1.0)
# 일반: 25 * 1.0 = 25
# 크리: 25 * 2.0 = 50
```

### GDScript 삼항 연산자

```gdscript
# Python과 동일한 문법
var result := (값_if_true) if (조건) else (값_if_false)

# 예:
var dmg := 50.0 if is_crit else 25.0
```

---

## 3. 적의 데미지 처리 (enemy.gd)

### take_damage 함수

```gdscript
func take_damage(amount: float, is_crit: bool = false) -> void:
    if not is_alive:
        return               # 이미 죽은 적은 무시

    current_hp -= amount     # HP 감소
    _update_hp_bar()          # HP 바 시각 업데이트
    _spawn_damage_number(amount, is_crit)  # 데미지 숫자 표시

    if current_hp <= 0.0:
        _die()               # 사망 처리
```

**`is_crit: bool = false`**: 기본값이 있는 매개변수. 크리티컬 정보를 안 넘기면 자동으로 `false`가 됩니다. 이렇게 하면 화염방사기처럼 크리티컬이 없는 공격에서도 같은 함수를 쓸 수 있습니다.

### HP 바 업데이트

```gdscript
func _update_hp_bar() -> void:
    var ratio := clampf(current_hp / max_hp, 0.0, 1.0)  # 0~1 비율

    # 채움 바의 X 스케일을 비율에 맞게 조절
    _hp_fill.scale.x = ratio

    # 스케일은 중심 기준이므로, 왼쪽 정렬을 위해 위치 보정
    _hp_fill.position.x = (ratio - 1.0) * 0.5

    # 숫자 텍스트 업데이트
    if _hp_label:
        _hp_label.text = "%d / %d" % [ceili(maxf(current_hp, 0.0)), int(max_hp)]
```

**스케일과 위치 보정 설명:**

```
HP 100%:  scale.x = 1.0,  position.x = 0.0
[████████████████████]

HP 50%:   scale.x = 0.5,  position.x = -0.25
     [██████████]           ← 중심 기준으로 줄어들면 양쪽이 줄어듦
[██████████]                ← position.x를 보정하면 왼쪽 정렬

계산: position.x = (0.5 - 1.0) * 0.5 = -0.25
```

HP 바의 원래 크기는 1.0 단위입니다. 스케일이 중심 기준으로 적용되므로, 왼쪽 끝을 고정하려면 `(ratio - 1.0) * 0.5`만큼 왼쪽으로 이동시켜야 합니다.

---

## 4. 데미지 숫자 (Floating Combat Text)

적이 피해를 받으면 머리 위에 데미지 숫자가 떠오릅니다.

### 생성 코드 (enemy.gd)

```gdscript
func _spawn_damage_number(amount: float, is_crit: bool) -> void:
    var node := Node3D.new()
    # 적 위치에서 약간 랜덤 오프셋
    node.global_position = global_position + Vector3(
        randf_range(-0.3, 0.3),  # X 랜덤
        2.5,                       # 머리 위
        randf_range(-0.3, 0.3)   # Z 랜덤
    )

    var label := Label3D.new()
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # 항상 카메라를 바라봄
    label.no_depth_test = true    # 다른 물체에 가려지지 않음
    label.render_priority = 10    # 다른 것 위에 렌더링
    label.outline_size = 8        # 검은 외곽선 (가독성)
    label.outline_modulate = Color(0, 0, 0, 0.8)
```

### 일반 vs 크리티컬 스타일

```gdscript
    if is_crit:
        label.text = str(int(amount)) + "!"   # "80!"
        label.font_size = 48                   # 크게
        label.modulate = Color(1.0, 0.2, 0.1) # 빨간색
        node.scale = Vector3(1.5, 1.5, 1.5)   # 초기 스케일 1.5배
    else:
        label.text = str(int(amount))          # "25"
        label.font_size = 28                   # 작게
        label.modulate = Color(1.0, 0.9, 0.2) # 노란색
```

### 떠오르며 사라지는 애니메이션

```gdscript
    node.add_child(label)
    get_tree().current_scene.add_child(node)  # 씬 루트에 추가 (적의 자식 아님!)

    var tween := node.create_tween()

    # 위로 1.5 유닛 떠오름 (0.8초, 감속 커브)
    tween.tween_property(node, "position:y", node.position.y + 1.5, 0.8) \
        .set_ease(Tween.EASE_OUT) \
        .set_trans(Tween.TRANS_CUBIC)

    # 동시에: 0.3초 후부터 투명해짐
    tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8) \
        .set_delay(0.3)

    # 크리티컬: 1.5배에서 1배로 축소 (임팩트 효과)
    if is_crit:
        tween.parallel().tween_property(node, "scale", Vector3.ONE, 0.3) \
            .set_ease(Tween.EASE_OUT)

    # 애니메이션 끝나면 자체 삭제
    tween.tween_callback(node.queue_free)
```

**`get_tree().current_scene.add_child(node)`를 쓰는 이유:**

적의 자식으로 추가하면(`add_child(node)`), 적이 죽어서 `visible = false`가 되면 데미지 숫자도 함께 사라집니다. 씬 루트에 추가하면 적과 독립적으로 동작합니다.

---

## 5. 적 사망과 리스폰

### 사망 처리

```gdscript
func _die() -> void:
    is_alive = false
    visible = false                          # 보이지 않게
    $CollisionShape3D.disabled = true        # 충돌 비활성화

    # 1~5초 후 리스폰 타이머 설정
    get_tree().create_timer(randf_range(1.0, 5.0)).timeout.connect(_respawn)
```

**`create_timer` + 시그널 패턴:**
```gdscript
get_tree().create_timer(3.0)   # SceneTreeTimer 생성 (3초)
    .timeout                    # timeout 시그널
    .connect(_respawn)          # _respawn 함수 연결
```
이것은 "3초 후에 `_respawn()` 호출"과 같습니다.

### 리스폰

```gdscript
func _respawn() -> void:
    current_hp = max_hp               # HP 복구
    _update_hp_bar()
    global_position = _find_clear_position()  # 안전한 위치 찾기
    is_alive = true
    visible = true
    $CollisionShape3D.disabled = false
```

### 안전한 리스폰 위치 찾기

물체와 겹치지 않는 위치를 찾는 로직입니다:

```gdscript
func _find_clear_position() -> Vector3:
    var space := get_world_3d().direct_space_state
    var shape := CapsuleShape3D.new()
    shape.radius = 0.8
    shape.height = 2.0

    for i in 30:  # 최대 30번 시도
        # 랜덤 위치 생성
        var x := randf_range(-8.0, 8.0)
        var z := randf_range(-8.0, 8.0)

        # 물리 오버랩 테스트
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = shape
        query.transform = Transform3D(Basis.IDENTITY, Vector3(x, 1.0, z))
        query.exclude = [get_rid()]         # 자기 자신 제외
        query.collision_mask = 0xFFFFFFFF   # 모든 레이어 체크

        var results := space.intersect_shape(query)
        # 바닥만 겹치면 (1개) 안전한 위치
        if results.size() <= 1:
            return Vector3(x, 0.0, z)

    # 30번 실패하면 그냥 랜덤 위치
    return Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
```

**`intersect_shape`:**
- 지정한 모양(캡슐)을 지정한 위치에 놓았을 때 겹치는 물체를 찾음
- `results.size() <= 1`: 바닥(Ground)만 겹치면 빈 공간
- `results.size() > 1`: 다른 물체(박스, 플레이어 등)와도 겹침 → 다시 시도

---

## 6. HP 바 (3D 빌보드)

### 구조 (enemy.tscn)

```
HPBar (Node3D) - position: (0, 2.3, 0)
├── Background (MeshInstance3D) - 회색 BoxMesh 1x0.1x0.02
└── Fill (MeshInstance3D)       - 초록 BoxMesh 1x0.1x0.02, Z +0.011
```

Fill의 Z가 Background보다 약간 앞에 있어서(`0.011`) 겹치지 않고 위에 표시됩니다.

### 빌보드 (항상 카메라를 향하게)

```gdscript
func _process(_delta: float) -> void:
    var camera := get_viewport().get_camera_3d()
    if camera and _hp_bar:
        # HP 바의 회전을 카메라와 동일하게 설정
        _hp_bar.global_rotation = camera.global_rotation
```

**빌보드(billboard)**: 3D 오브젝트가 항상 카메라를 정면으로 바라보는 기법. HP 바, 이름표 등에 사용합니다.

Label3D의 경우 속성으로 간단히 설정 가능:
```gdscript
label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
```

MeshInstance3D의 경우 코드에서 직접 회전을 맞춰야 합니다.

---

## 7. 플레이어 HP 바

플레이어도 동일한 구조의 HP 바를 가지지만, 코드에서 생성합니다 (player.gd: `_create_hp_bar()`):

```gdscript
func _create_hp_bar() -> void:
    _hp_bar_node = Node3D.new()
    _hp_bar_node.position = Vector3(0, 2.3, 0)  # 머리 위
    add_child(_hp_bar_node)

    var bar_mesh := BoxMesh.new()
    bar_mesh.size = Vector3(1, 0.1, 0.02)

    # 배경 바
    var bg := MeshInstance3D.new()
    bg.mesh = bar_mesh
    var bg_mat := StandardMaterial3D.new()
    bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bg_mat.albedo_color = Color(0.2, 0.2, 0.2, 1)
    bg.material_override = bg_mat
    _hp_bar_node.add_child(bg)

    # 채움 바 (동일 메시, 다른 재질, Z +0.011)
    _hp_fill_mesh = MeshInstance3D.new()
    _hp_fill_mesh.mesh = bar_mesh
    _hp_fill_mesh.position.z = 0.011
    var fill_mat := StandardMaterial3D.new()
    fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fill_mat.albedo_color = Color(0.1, 0.8, 0.1, 1)
    _hp_fill_mesh.material_override = fill_mat
    _hp_bar_node.add_child(_hp_fill_mesh)

    # HP 숫자 (Label3D)
    _hp_label_3d = Label3D.new()
    _hp_label_3d.font_size = 16
    _hp_label_3d.pixel_size = 0.005
    _hp_label_3d.position = Vector3(0, 0.12, 0.02)
    _hp_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    # ...
```

**`.tscn`에서 만들기 vs 코드에서 만들기:**
- 적의 HP 바: `.tscn`에 정의 → 에디터에서 보이고 편집 가능
- 플레이어의 HP 바: 코드에서 생성 → 에디터에서 안 보이지만 유연함
- 둘 다 유효한 방식이고, 프로젝트에서 두 방식을 모두 경험해볼 수 있습니다

---

## 다음 단계

[05. 스킬 시스템](05-skill-system.md)에서 번개와 화염방사기 스킬을 살펴봅니다.
