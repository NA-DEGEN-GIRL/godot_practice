# 05. 스킬 시스템

이 문서는 스킬 프레임워크, 번개 스킬, 화염방사기 스킬의 구현을 설명합니다.

---

## 1. 스킬 프레임워크 (player.gd)

### 데이터 구조

```gdscript
# 각 스킬의 현재 남은 쿨타임 (0이면 사용 가능)
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]

# 각 스킬의 최대 쿨타임 (0이면 미구현 스킬)
var skill_max_cooldowns: Array[float] = [1.0, 5.0, 0.0, 0.0]
#                                        ⚡1초  🔥5초  미구현  미구현
```

**배열 인덱스 = 스킬 슬롯:**
- `[0]` = 1번 키 (번개)
- `[1]` = 2번 키 (화염방사기)
- `[2]` = 3번 키 (미구현)
- `[3]` = 4번 키 (미구현)

### 쿨타임 감소 (매 물리 프레임)

```gdscript
func _physics_process(delta: float) -> void:
    for i in skill_cooldowns.size():
        if skill_cooldowns[i] > 0.0:
            skill_cooldowns[i] = maxf(skill_cooldowns[i] - delta, 0.0)
```

`maxf(..., 0.0)`: 0 미만으로 내려가지 않도록 보장합니다.

### 키 입력 처리

```gdscript
elif event is InputEventKey:
    if event.pressed and not event.echo:  # 키 누름 (반복 입력 아님)
        match event.keycode:
            KEY_1: _use_skill(0)          # 번개 (즉발형)
            KEY_2: _start_flamethrower()  # 화염 (홀드형 - 별도 처리)
            KEY_3: _use_skill(2)
            KEY_4: _use_skill(3)
    elif not event.pressed:                # 키 뗌
        match event.keycode:
            KEY_2: _stop_flamethrower()   # 화염 중지
```

**`not event.echo`**: 키를 꾹 누르고 있으면 OS가 반복 입력(echo)을 보냅니다. 이걸 무시해야 스킬이 한 번만 발동됩니다.

**번개 vs 화염방사기의 입력 차이:**
- 번개: 키 누르면 즉시 발동 → `_use_skill(0)` 한 번 호출
- 화염: 키 누르면 시작, 떼면 중지 → `_start/_stop_flamethrower()` 쌍

---

## 2. 즉발형 스킬: _use_skill()

```gdscript
func _use_skill(index: int) -> void:
    # 1. 쿨타임 체크
    if skill_cooldowns[index] > 0.0 or skill_max_cooldowns[index] <= 0.0:
        return  # 쿨타임 중이거나 미구현 스킬

    # 2. 마우스 위치에서 레이캐스트
    var camera := get_viewport().get_camera_3d()
    var mouse_pos := get_viewport().get_mouse_position()
    var from := camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos)

    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
    query.exclude = [get_rid()]
    var result := space.intersect_ray(query)

    # 3. 마우스 아래에 적이 있는지 확인
    if not result or not result.collider.is_in_group("enemy"):
        return  # 적이 없으면 취소
    var enemy: Node3D = result.collider
    if not enemy.visible:
        return  # 죽은(숨겨진) 적이면 취소

    # 4. 사정거리 체크
    if global_position.distance_to(enemy.global_position) > skill_range:
        return  # 너무 멀면 취소

    # 5. 쿨타임 시작 + 스킬 실행
    skill_cooldowns[index] = skill_max_cooldowns[index]

    match index:
        0: _cast_lightning(enemy)
```

**유효성 검사 순서가 중요합니다:**
1. 쿨타임 체크 (가장 빠른 체크)
2. 카메라/레이캐스트 (약간 비용)
3. 적 존재 확인
4. 적 상태 확인 (살아있는지)
5. 거리 확인
6. 실행

비용이 적은 검사를 먼저 하고, 비용이 큰 검사를 나중에 합니다.

---

## 3. 번개 스킬 (Skill 1)

### 발동 (player.gd)

```gdscript
func _cast_lightning(enemy: Node3D) -> void:
    # 크리티컬 판정
    var is_crit := randf() < crit_chance
    var dmg := 40.0 * (crit_multiplier if is_crit else 1.0)
    enemy.take_damage(dmg, is_crit)

    # 효과음
    _sfx_lightning.play()

    # 이펙트 생성
    var effect := _lightning_scene.instantiate()
    effect.global_position = enemy.global_position
    get_tree().current_scene.add_child(effect)
```

### 번개 이펙트 (lightning_effect.gd)

번개 이펙트는 **절차적(procedural)**으로 생성됩니다. 미리 만든 모델이 아니라 코드로 메시를 실시간 생성합니다.

#### 3-1. 지그재그 경로 생성

```gdscript
func _zigzag_points(segments: int, height: float, spread: float) -> PackedVector3Array:
    var points := PackedVector3Array()
    var offset := Vector2.ZERO

    for i in segments + 1:
        var t := float(i) / segments  # 0.0 → 1.0 진행률
        var y := height * (1.0 - t)   # 위에서 아래로

        if i == 0 or i == segments:
            offset = Vector2.ZERO      # 시작점과 끝점은 정중앙
        else:
            # 랜덤 오프셋 누적 (지그재그)
            offset += Vector2(
                randf_range(-spread, spread),
                randf_range(-spread, spread)
            )
            offset *= 0.8  # 감쇠: 너무 많이 벗어나지 않게

        points.append(Vector3(offset.x, y, offset.y))

    return points
```

**감쇠(`offset *= 0.8`)의 역할:**
- 오프셋이 계속 누적되면 번개가 옆으로 크게 벗어남
- 0.8을 곱하면 이전 오프셋의 영향이 점차 줄어듦
- 결과: 자연스러운 지그재그 (너무 직선도 아니고 너무 랜덤도 아님)

#### 3-2. 크로스 리본 메시 (ImmediateMesh)

번개의 시각적 표현은 **두 개의 수직 평면**으로 이루어집니다:

```
정면에서:    위에서:
  │           ──┼──
 ╱│╲           │
╱ │ ╲    X축 리본과 Z축 리본이
│ │ │    십자(+) 형태로 교차
╲ │ ╱
 ╲│╱
  │
```

```gdscript
func _build_cross_ribbon(points: PackedVector3Array, width: float) -> ImmediateMesh:
    var im := ImmediateMesh.new()

    # X축 리본 (좌-우 방향 폭)
    im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
    for p in points:
        im.surface_add_vertex(Vector3(p.x - width, p.y, p.z))  # 왼쪽
        im.surface_add_vertex(Vector3(p.x + width, p.y, p.z))  # 오른쪽
    im.surface_end()

    # Z축 리본 (앞-뒤 방향 폭) - 수직으로 교차
    im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
    for p in points:
        im.surface_add_vertex(Vector3(p.x, p.y, p.z - width))  # 앞
        im.surface_add_vertex(Vector3(p.x, p.y, p.z + width))  # 뒤
    im.surface_end()

    return im
```

**왜 크로스(십자) 형태인가?**
- 단일 평면이면 옆에서 보면 선처럼 보임 (두께 없음)
- 두 평면을 수직으로 교차시키면 어느 각도에서든 볼 수 있음
- 빌보드 방식보다 가볍고, 아이소메트릭 뷰에 적합

**ImmediateMesh란?**
- 코드에서 직접 버텍스(꼭짓점)를 찍어 메시를 만드는 방식
- `surface_begin()` → `surface_add_vertex()` 반복 → `surface_end()`
- `PRIMITIVE_TRIANGLE_STRIP`: 연속된 삼각형 띠

```
Triangle Strip:
  1───3───5
  │╲  │╲  │
  │ ╲ │ ╲ │
  2───4───6
  → 삼각형: (1,2,3), (2,3,4), (3,4,5), (4,5,6)
```

#### 3-3. 볼트 레이어링

```gdscript
func _ready() -> void:
    # 1. 글로우 볼트 (넓고 투명 - 빛나는 느낌)
    add_child(_create_bolt(BOLT_SEGMENTS, BOLT_HEIGHT, BOLT_SPREAD, 0.15,
        Color(0.4, 0.6, 1.0, 0.3), 2.0))

    # 2. 메인 볼트 (얇고 밝음 - 핵심 번개)
    add_child(_create_bolt(BOLT_SEGMENTS, BOLT_HEIGHT, BOLT_SPREAD, 0.05,
        Color(0.85, 0.95, 1.0, 0.95), 4.0))

    # 3. 가지 볼트 (짧고 비스듬히)
    var branch := _create_bolt(5, 3.0, 0.3, 0.03, ...)
    branch.position = Vector3(랜덤, 랜덤높이, 랜덤)
    branch.rotation.z = randf_range(0.3, 0.7) * side  # 비스듬히
```

**레이어링 효과:**
```
글로우(넓고 투명):  ░░░▓░░░
메인(얇고 밝음):       ║
가지:                 ╱
합성 결과:        ░░░▓║░░░  ← 중심이 밝고 주변이 빛나는 번개
                      ╱
```

#### 3-4. 페이드아웃 애니메이션

```gdscript
    var tween := create_tween()

    # 빛 깜박임 (번쩍)
    tween.tween_property($Flash, "light_energy", 2.0, 0.04)   # 어두워짐
    tween.tween_property($Flash, "light_energy", 6.0, 0.04)   # 밝아짐

    # 모든 메시를 투명하게 + 빛 꺼짐
    for child in get_children():
        if child is MeshInstance3D:
            tween.parallel().tween_property(child, "transparency", 1.0, 0.25)
    tween.parallel().tween_property($Flash, "light_energy", 0.0, 0.25)

    # 완료 후 삭제
    tween.tween_callback(queue_free)
```

---

## 4. 화염방사기 스킬 (Skill 2)

화염방사기는 번개와 달리 **지속형(hold)** 스킬입니다.

### 상태 머신

```
[대기] ──(2번 누름)──→ [발사 중] ──(2번 뗌 or 5초)──→ [쿨타임]
                         │                                │
                         │ 매 프레임:                      │ 5초 대기
                         │ - 방향 업데이트                  │
                         │ - 데미지 틱                      ▼
                         │                              [대기]
                         ▼
```

### 시작 (player.gd)

```gdscript
func _start_flamethrower() -> void:
    if skill_cooldowns[1] > 0.0 or _flamethrower_active:
        return                    # 쿨타임 중이거나 이미 사용 중

    _flamethrower_active = true
    _flamethrower_time = 0.0
    _sfx_fire.play()              # 효과음 시작

    # 이펙트를 플레이어의 자식으로 생성
    _flamethrower_effect = _flamethrower_scene.instantiate()
    _flamethrower_effect.position = Vector3(0, 1, 0)  # 가슴 높이
    add_child(_flamethrower_effect)
```

### 매 프레임 업데이트 (player.gd)

```gdscript
func _update_flamethrower(delta: float) -> void:
    if not _flamethrower_active or not _flamethrower_effect:
        return

    _flamethrower_time += delta
    if _flamethrower_time >= FLAMETHROWER_MAX_DURATION:  # 5초 제한
        _stop_flamethrower()
        return

    # 마우스 방향으로 회전
    var ground_pos := _get_mouse_ground_pos()
    var dir := ground_pos - global_position
    dir.y = 0.0
    if dir.length_squared() > 0.01:
        _flamethrower_effect.rotation.y = atan2(-dir.x, -dir.z)
```

**방향 계산 (`atan2`):**

Godot에서 -Z가 "앞"이므로:
```gdscript
rotation.y = atan2(-dir.x, -dir.z)
```

```
dir = (0, 0, 1)  → atan2(0, -1)  = π    → 뒤쪽을 향함 (반대로 회전)
dir = (1, 0, 0)  → atan2(-1, 0)  = -π/2 → 오른쪽을 향함
dir = (0, 0, -1) → atan2(0, 1)   = 0    → 앞쪽 (-Z, 기본 방향)
```

### 중지 (player.gd)

```gdscript
func _stop_flamethrower() -> void:
    if not _flamethrower_active:
        return
    _flamethrower_active = false
    _sfx_fire.stop()                                    # 소리 중지

    if _flamethrower_effect and is_instance_valid(_flamethrower_effect):
        _flamethrower_effect.stop()                     # 이펙트 페이드아웃
        _flamethrower_effect = null

    skill_cooldowns[1] = skill_max_cooldowns[1]         # 쿨타임 시작 (5초)
```

### 이펙트 (flamethrower_effect.gd)

이펙트는 **GPUParticles3D** (파티클)과 **Area3D** (데미지 영역)으로 구성됩니다.

#### 파티클 설정

```gdscript
func _setup_particles() -> void:
    var particles := GPUParticles3D.new()
    particles.amount = 64           # 파티클 수
    particles.lifetime = 0.5        # 각 파티클 수명

    var mat := ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 0, -1)   # -Z 방향으로 발사
    mat.spread = 20.0                    # 20도 퍼짐
    mat.initial_velocity_min = 6.0       # 최소 속도
    mat.initial_velocity_max = 8.0       # 최대 속도
    mat.gravity = Vector3(0, 1.5, 0)     # 약간 위로 떠오름 (열기)
    mat.damping_min = 1.0                # 감속
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat.emission_sphere_radius = 0.15    # 발사 원점 약간 퍼뜨림
```

#### 색상 그라데이션 (시간에 따라)

```gdscript
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([
        Color(1.0, 0.95, 0.4, 0.9),   # 시작: 밝은 노랑
        Color(1.0, 0.55, 0.1, 0.8),   # 중간: 주황
        Color(0.9, 0.2, 0.0, 0.4),    # 후반: 빨강, 반투명
        Color(0.3, 0.1, 0.0, 0.0)     # 끝: 어두운 빨강, 완전 투명
    ])
    gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
    mat.color_ramp = grad_tex  # 파티클 수명 동안 이 색상 변화 적용
```

#### 데미지 영역 (Area3D)

```gdscript
func _setup_damage_area() -> void:
    _area = Area3D.new()
    _area.collision_layer = 0       # 다른 것이 이걸 감지 못함
    _area.collision_mask = 1        # 레이어 1의 물체를 감지

    var shape := BoxShape3D.new()
    shape.size = Vector3(2.0, 2.0, FLAME_LENGTH)  # 폭2 x 높이2 x 길이4

    var col := CollisionShape3D.new()
    col.shape = shape
    col.position = Vector3(0, 0, -FLAME_LENGTH / 2.0)  # 앞쪽으로 배치
    _area.add_child(col)
    add_child(_area)
```

```
위에서 본 데미지 영역:

    플레이어 ●━━━━━━━━━┓
             ┃  Area3D  ┃  ← 폭 2.0, 길이 4.0
             ┗━━━━━━━━━┛
                         → 화염 방향 (-Z)
```

#### 데미지 틱

```gdscript
const DAMAGE_TICK := 0.5  # 0.5초마다 데미지
var _damage_timer: float = 0.0

func _physics_process(delta: float) -> void:
    _damage_timer += delta
    if _damage_timer >= DAMAGE_TICK:
        _damage_timer -= DAMAGE_TICK
        for body in _area.get_overlapping_bodies():
            if body.is_in_group("enemy") and body.has_method("take_damage"):
                body.take_damage(DAMAGE_PER_SECOND * DAMAGE_TICK)
                # 15.0 * 0.5 = 7.5 데미지/틱
```

**왜 매 프레임이 아니라 틱인가?**
- 매 프레임: 60fps에서 초당 60번 → 데미지 숫자가 60개 생성 → 화면이 숫자로 가득 참
- 0.5초 틱: 초당 2번 → 적절한 빈도의 데미지 숫자

#### 정지 (페이드아웃)

```gdscript
func stop() -> void:
    _area.monitoring = false     # 데미지 즉시 중지
    set_physics_process(false)   # 물리 처리 중지

    for child in get_children():
        if child is GPUParticles3D:
            child.emitting = false   # 새 파티클 생성 중지
        elif child is OmniLight3D:
            child.light_energy = 0.0  # 빛 즉시 끄기

    var tween := create_tween()
    tween.tween_interval(0.6)    # 기존 파티클이 사라질 때까지 대기
    tween.tween_callback(queue_free)  # 노드 삭제
```

**`emitting = false`**: 새 파티클 생성은 멈추지만, 이미 존재하는 파티클은 수명이 다할 때까지 계속 보입니다. 이렇게 하면 자연스러운 페이드아웃이 됩니다.

---

## 5. 사운드 루프 (화염방사기)

```gdscript
# _ready에서 연결
_sfx_fire.finished.connect(_on_fire_sfx_finished)

# 사운드 재생 완료 시
func _on_fire_sfx_finished() -> void:
    if _flamethrower_active:
        _sfx_fire.play()  # 아직 사용 중이면 다시 재생
```

WAV 파일의 루프 설정 대신, `finished` 시그널로 사운드를 반복합니다. 이 방식이 더 안전합니다 (WAV 압축 포맷에 따라 루프 설정이 호환되지 않을 수 있음).

---

## 다음 단계

[06. UI와 HUD](06-ui-and-hud.md)에서 스킬바, HP/SP 게이지, 쿨타임 애니메이션을 살펴봅니다.
