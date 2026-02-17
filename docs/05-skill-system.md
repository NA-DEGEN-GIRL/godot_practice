# 05. 스킬 시스템

이 문서는 스킬 프레임워크, 번개 스킬, 화염방사기 스킬, 순간이동 스킬의 구현을 설명합니다.

---

## 1. 스킬 프레임워크 (player.gd)

### 데이터 구조

```gdscript
# 각 스킬의 현재 남은 쿨타임 (0이면 사용 가능)
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]

# 각 스킬의 최대 쿨타임 (0이면 미구현 스킬)
var skill_max_cooldowns: Array[float] = [1.0, 5.0, 10.0, 0.0]
#                                        ⚡1초  🔥5초  💨10초  미구현
```

**배열 인덱스 = 스킬 슬롯:**
- `[0]` = 1번 키 (번개)
- `[1]` = 2번 키 (화염방사기)
- `[2]` = 3번 키 (순간이동)
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
            KEY_3: _cast_teleport()  # 순간이동 (별도 처리)
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

## 5. 순간이동 스킬 (Skill 3)

순간이동은 번개/화염과 달리 **적을 대상으로 하지 않는** 스킬입니다. 마우스 방향으로 일정 거리를 즉시 이동합니다.

### 상태 머신

```
[대기] ──(3번 누름)──→ [방향 계산] → [목적지 검증] → [이동] → [쿨타임 10초]
                                                                    │
                                                                    ▼
                                                                 [대기]
```

### 발동 (player.gd)

```gdscript
func _cast_teleport() -> void:
    # 1. 쿨타임 체크
    if skill_cooldowns[2] > 0.0:
        return

    # 2. 마우스 방향 계산
    var ground_pos := _get_mouse_ground_pos()
    var dir := ground_pos - global_position
    dir.y = 0.0
    if dir.length_squared() < 0.01:
        return  # 마우스가 캐릭터 바로 위에 있으면 무시
    dir = dir.normalized()

    # 3. 목적지 계산
    var dest := global_position + dir * TELEPORT_DISTANCE  # 5.0 거리
    dest.y = 0.0

    # 4. 맵 경계 클램핑
    dest.x = clampf(dest.x, -9.5, 9.5)
    dest.z = clampf(dest.z, -9.5, 9.5)

    # 5. 장애물 충돌 체크 (겹침 방지)
    dest = _find_clear_teleport_pos(dest)

    # 6. 쿨타임 시작
    skill_cooldowns[2] = skill_max_cooldowns[2]  # 10초

    # 7. 효과음 + 출발 이펙트
    _sfx_teleport.play()
    var depart_fx := _teleport_scene.instantiate()
    depart_fx.global_position = global_position + Vector3(0, 0.5, 0)
    get_tree().current_scene.add_child(depart_fx)

    # 8. 실제 순간이동
    global_position = dest
    _target = dest
    _moving = false
    _attack_target = null
    velocity = Vector3.ZERO

    # 9. 도착 이펙트
    var arrive_fx := _teleport_scene.instantiate()
    arrive_fx.global_position = dest + Vector3(0, 0.5, 0)
    get_tree().current_scene.add_child(arrive_fx)

    # 10. 카메라 흔들림
    var camera := get_viewport().get_camera_3d()
    if camera and camera.has_method("shake"):
        camera.shake(0.25, 0.15)
```

**번개/화염과의 차이:**
- 적 대상 X → 마우스 방향으로 발동
- `_use_skill()` 프레임워크 사용 X → 별도 함수 `_cast_teleport()`
- 출발점 + 도착점 양쪽에 이펙트 생성

### 목적지 충돌 체크 (_find_clear_teleport_pos)

순간이동 도착 지점에 장애물이 있으면 캐릭터가 끼일 수 있습니다. 이를 방지하기 위해 `intersect_shape`로 도착 지점을 검증합니다.

```gdscript
func _find_clear_teleport_pos(target: Vector3) -> Vector3:
    var space := get_world_3d().direct_space_state
    var shape := SphereShape3D.new()
    shape.radius = 0.5

    var params := PhysicsShapeQueryParameters3D.new()
    params.shape = shape
    params.transform = Transform3D(Basis.IDENTITY, target + Vector3(0, 1, 0))
    params.exclude = [get_rid()]        # 자기 자신 제외
    params.collide_with_areas = false   # Area3D 무시

    # 충돌 체크 후 바닥(Ground) 필터링
    var hits := space.intersect_shape(params, 8)
    hits = hits.filter(func(h):
        return h.collider != null and not (
            h.collider is StaticBody3D and h.collider.name == "Ground"
        )
    )

    if hits.is_empty():
        return target  # 장애물 없음 → 그대로 이동

    # 장애물 있음 → 더 짧은 거리 시도
    var dir := (target - global_position).normalized()
    for step in range(4, 0, -1):
        var test_pos := global_position + dir * (TELEPORT_DISTANCE * step / 5.0)
        # ... 같은 충돌 체크 반복 ...
        if hits.is_empty():
            return test_pos

    # 모든 위치가 막힘 → 제자리 (스킬 쿨타임만 소모)
    return global_position
```

**`intersect_shape` vs `intersect_ray`:**
- `intersect_ray`: 직선으로 물체를 "뚫고" 지나가는지 확인 (레이캐스트)
- `intersect_shape`: 특정 모양(구, 캡슐 등)이 다른 물체와 **겹치는지** 확인
- 순간이동은 "도착 지점에 공간이 있는가"를 확인해야 하므로 `intersect_shape`가 적합

**바닥 필터링이 필요한 이유:**
- 모든 물리 오브젝트가 collision_layer 1에 있음
- `intersect_shape`는 바닥(Ground)도 감지
- 바닥은 통과 가능한 표면이므로 수동으로 필터링

**폴백 전략 (거리 축소):**
```
목적지(5.0) 충돌 → 거리 4.0 시도 → 거리 3.0 시도 → 거리 2.0 시도 → 거리 1.0 시도
모두 실패하면 → 제자리 (쿨타임만 소모)
```

### 이펙트 (teleport_effect.gd)

순간이동 이펙트는 파티클 폭발 + 빛 플래시로 구성됩니다.

```gdscript
func _ready() -> void:
    _setup_particles()  # 파란/보라 파티클 폭발
    _setup_light()      # OmniLight3D 플래시

    # 1초 후 자동 삭제
    var tween := create_tween()
    tween.tween_interval(1.0)
    tween.tween_callback(queue_free)
```

#### 파티클 (원샷 폭발)

```gdscript
func _setup_particles() -> void:
    var particles := GPUParticles3D.new()
    particles.amount = 32
    particles.lifetime = 0.6
    particles.one_shot = true        # 한 번만 발사
    particles.explosiveness = 1.0    # 모든 파티클 동시 발사

    var mat := ParticleProcessMaterial.new()
    mat.direction = Vector3(0, 1, 0)     # 위쪽으로
    mat.spread = 180.0                    # 전방향 (구형 폭발)
    mat.initial_velocity_min = 3.0
    mat.initial_velocity_max = 5.0
    mat.gravity = Vector3(0, -2.0, 0)    # 자연스럽게 떨어짐
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    mat.emission_sphere_radius = 0.3
```

**`one_shot = true` + `explosiveness = 1.0`:**
- `one_shot`: 파티클을 한 번만 생성 (반복 X)
- `explosiveness = 1.0`: 모든 파티클을 동시에 발사 (0.0이면 lifetime 동안 분산 발사)
- 조합하면 "폭발" 효과 완성

#### 색상 그라데이션 (파란색 → 보라색 → 투명)

```gdscript
    gradient.colors = PackedColorArray([
        Color(0.5, 0.7, 1.0, 0.9),   # 시작: 밝은 파랑
        Color(0.6, 0.4, 1.0, 0.6),   # 중간: 보라
        Color(0.3, 0.2, 0.8, 0.0)    # 끝: 어두운 보라, 투명
    ])
```

#### 빛 플래시 (OmniLight3D)

```gdscript
func _setup_light() -> void:
    var light := OmniLight3D.new()
    light.light_color = Color(0.5, 0.4, 1.0)  # 보라빛
    light.light_energy = 5.0                    # 강한 밝기
    light.omni_range = 4.0

    # 빠르게 페이드아웃
    var tween := create_tween()
    tween.tween_property(light, "light_energy", 0.0, 0.4)
```

### 카메라 흔들림 (camera_follow.gd)

```gdscript
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0

func shake(duration: float, intensity: float) -> void:
    _shake_duration = duration
    _shake_intensity = intensity
    _shake_time = 0.0

func _process(delta: float) -> void:
    # ... 기존 카메라 추적 코드 ...

    if _shake_time < _shake_duration:
        _shake_time += delta
        var decay := 1.0 - (_shake_time / _shake_duration)  # 1.0 → 0.0 감쇠
        global_position += Vector3(
            randf_range(-1.0, 1.0) * _shake_intensity * decay,
            randf_range(-1.0, 1.0) * _shake_intensity * decay * 0.5,
            randf_range(-1.0, 1.0) * _shake_intensity * decay
        )
```

**감쇠(decay)의 역할:**
```
시작: decay = 1.0 → 흔들림 100%   ████████████
중간: decay = 0.5 → 흔들림 50%    ██████
끝:   decay = 0.0 → 흔들림 0%     (정지)
```

Y축 흔들림은 `* 0.5`로 절반만 적용합니다. 수직 흔들림이 과하면 부자연스럽기 때문입니다.

---

## 6. 사운드 루프 (화염방사기)

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

## 7. 스킬별 비교 요약

| 항목 | 번개 (1) | 화염방사기 (2) | 순간이동 (3) |
|------|----------|---------------|-------------|
| **타입** | 즉발형 | 지속형 (홀드) | 즉발형 |
| **대상** | 적 지정 | 범위 (Area3D) | 방향 지정 |
| **쿨타임** | 1초 | 5초 | 10초 |
| **데미지** | 40 (크리티컬 가능) | 15/초 (틱) | 없음 |
| **이펙트** | ImmediateMesh 지그재그 | GPUParticles3D 지속 | GPUParticles3D 원샷 폭발 |
| **사운드** | 즉시 재생 | finished 시그널 루프 | 즉시 재생 |
| **특수** | 크로스 리본 메시 | 방향 추적, 최대 시간 | 충돌 체크, 카메라 흔들림 |

---

## 다음 단계

[06. UI와 HUD](06-ui-and-hud.md)에서 스킬바, HP/SP 게이지, 쿨타임 애니메이션을 살펴봅니다.
