# 03. 플레이어 이동 시스템

이 문서는 마우스 클릭으로 3D 캐릭터를 이동시키는 방법을 단계별로 설명합니다.

---

## 1. 핵심 개념: 화면 좌표 → 3D 좌표 변환

마우스 클릭은 **2D 화면 좌표**(픽셀)입니다. 3D 세계에서 "어디를 클릭했는지" 알려면 **레이캐스팅**이 필요합니다.

### 레이캐스팅이란?

카메라에서 마우스 위치를 통과하는 **광선(ray)**을 3D 공간으로 쏘는 것입니다:

```
카메라 ──────── ✦ 마우스 클릭 위치 ──────── → 3D 공간으로 광선
                     │
                     ▼
                  바닥(Y=0)과 만나는 점 = 이동 목표
```

### Orthographic vs Perspective

이 프로젝트는 **Orthographic(직교)** 카메라를 사용합니다:

```
Perspective (원근):          Orthographic (직교):
   카메라                       카메라
     \                          │ │ │
      \  \  \                   │ │ │
       \  \  \                  ▼ ▼ ▼
  ──────────────             ──────────────
  광선이 한 점에서 퍼져나감    광선이 모두 평행
```

- Perspective: 광선의 **시작점**은 카메라, **방향**은 카메라→마우스
- Orthographic: 광선의 **시작점**은 마우스 위치 평면 위, **방향**은 카메라가 바라보는 방향

Godot은 둘 다 같은 API로 처리합니다.

---

## 2. 코드 분석: 클릭 이동

### 2-1. 마우스 입력 감지 (player.gd)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    # 좌클릭 감지
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse_held = event.pressed     # 버튼 상태 추적
        if event.pressed:
            _handle_click(event.position)  # 클릭 처리

    # 드래그 (버튼 누른 채 이동)
    elif event is InputEventMouseMotion and _mouse_held:
        _handle_drag(event.position)
```

**`_unhandled_input` vs `_input`:**
- `_input`: 모든 입력을 최우선으로 받음
- `_unhandled_input`: UI 등에서 처리하지 않은 입력만 받음
- RPG에서는 `_unhandled_input`이 적합 (UI 클릭과 게임 클릭 구분)

### 2-2. 클릭 위치 판별 (레이캐스트)

```gdscript
func _handle_click(screen_pos: Vector2) -> void:
    var camera := get_viewport().get_camera_3d()
    if not camera:
        return

    # 카메라 API로 광선 생성
    var from := camera.project_ray_origin(screen_pos)   # 광선 시작점
    var dir := camera.project_ray_normal(screen_pos)     # 광선 방향 (정규화된 벡터)

    # 물리 엔진으로 레이캐스트
    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
        from,                   # 시작점
        from + dir * 100.0      # 끝점 (100미터 앞)
    )
    query.exclude = [get_rid()]  # 자기 자신은 제외
    var result := space.intersect_ray(query)
```

**`project_ray_origin`과 `project_ray_normal`:**
- Orthographic 카메라에서 `origin`은 마우스 위치에 해당하는 3D 점
- `normal`은 카메라가 바라보는 방향 (모든 픽셀에서 동일)

**레이캐스트 결과:**
```gdscript
result = {
    "position": Vector3(...),   # 충돌 지점
    "normal": Vector3(...),     # 충돌면의 법선
    "collider": Node,           # 충돌한 노드
    ...
}
# 아무것도 안 맞으면 result는 빈 Dictionary → falsy
```

### 2-3. 적 vs 빈 땅 판별

```gdscript
    if result and result.collider.is_in_group("enemy"):
        # 적을 클릭 → 공격 모드
        _attack_target = result.collider
        _target = _attack_target.global_position
        _moving = true
    else:
        # 빈 땅 → 이동 모드
        _attack_target = null
        _move_to_ground(from, dir)
```

### 2-4. 바닥(Y=0)과 광선의 교차점 계산

물리 레이캐스트로 적이 안 맞았을 때, 수학적으로 Y=0 평면과의 교차점을 구합니다:

```gdscript
func _move_to_ground(from: Vector3, dir: Vector3) -> void:
    if abs(dir.y) > 0.001:       # 광선이 수직이 아닌지 체크
        var t := -from.y / dir.y  # 매개변수 t 계산
        if t > 0.0:               # 카메라 앞쪽인지 체크
            var hit := from + dir * t  # 교차점 계산
            _target = Vector3(hit.x, 0.0, hit.z)
            _moving = true
```

**수학 설명:**
```
광선의 점: P(t) = from + dir * t    (t는 매개변수)
바닥:      Y = 0

Y=0에서의 t:
  from.y + dir.y * t = 0
  t = -from.y / dir.y

교차점:
  hit = from + dir * t
```

---

## 3. 실제 이동 (물리 프레임)

### 3-1. move_and_slide

```gdscript
func _physics_process(delta: float) -> void:
    # ...공격 로직 생략...

    if not _moving:
        velocity = Vector3.ZERO
        return

    var diff := _target - global_position
    diff.y = 0.0  # Y 성분 무시 (바닥 위에서만 이동)

    # 목표 근처에 도달하면 정지
    if diff.length() < 0.1:
        _moving = false
        velocity = Vector3.ZERO
        return

    # 속도 설정 후 이동
    velocity = diff.normalized() * move_speed
    move_and_slide()
```

**`move_and_slide()`란?**
- `CharacterBody3D`의 핵심 메서드
- `velocity` 속성을 읽어서 이동 + 충돌 처리
- 벽에 부딪히면 벽을 따라 미끄러짐 (slide)
- 충돌 정보는 `get_slide_collision()` 으로 얻을 수 있음

### 3-2. 맵 경계 제한

```gdscript
    # 이동 후 위치를 맵 범위로 제한
    global_position.x = clampf(global_position.x, -9.5, 9.5)
    global_position.z = clampf(global_position.z, -9.5, 9.5)
```

바닥이 20x20 크기(-10~10)이므로, 약간의 여유를 두고 -9.5~9.5로 제한합니다.

### 3-3. 물체 밀기

```gdscript
    # move_and_slide 후 충돌 체크
    for i in get_slide_collision_count():
        var collision := get_slide_collision(i)
        var collider := collision.get_collider()
        if collider is RigidBody3D:
            var push_dir := -collision.get_normal()  # 충돌 반대 방향 = 밀기 방향
            push_dir.y = 0.0  # 수평으로만 밀기
            collider.apply_central_impulse(push_dir * push_force)
```

- `get_slide_collision(i)`: i번째 충돌 정보
- `collision.get_normal()`: 충돌면의 법선 (자신을 향함)
- 법선의 반대 방향으로 RigidBody에 **충격(impulse)**을 가함

---

## 4. 드래그 이동 (디아블로 스타일)

```gdscript
var _mouse_held: bool = false  # 마우스 버튼 상태

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _mouse_held = event.pressed  # 누름/뗌 추적

    # 버튼 누른 채 마우스 움직이면 = 드래그
    elif event is InputEventMouseMotion and _mouse_held:
        _handle_drag(event.position)

func _handle_drag(screen_pos: Vector2) -> void:
    _attack_target = null  # 드래그 중엔 공격 취소
    var camera := get_viewport().get_camera_3d()
    # ...레이 계산...
    _move_to_ground(from, dir)  # 마우스 위치를 연속 추적
```

**동작 원리:**
1. 좌클릭 누름 → `_mouse_held = true`, 클릭 위치로 이동
2. 누른 채 마우스 이동 → 매번 새 위치로 이동 목표 갱신
3. 좌클릭 뗌 → `_mouse_held = false`, 마지막 위치로 계속 이동

---

## 5. 카메라 추적 (camera_follow.gd)

```gdscript
extends Camera3D

@export var follow_speed: float = 5.0
@export var target_path: NodePath = "../Player"

var _offset: Vector3    # 카메라↔플레이어 초기 거리
var _target: Node3D

func _ready() -> void:
    _target = get_node(target_path)
    _offset = global_position  # 초기 카메라 위치를 오프셋으로 저장
    if _target:
        global_position = _target.global_position + _offset

func _process(delta: float) -> void:
    if not _target:
        return
    var desired := _target.global_position + _offset
    # 프레임 독립적 부드러운 보간
    global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
```

### 프레임 독립적 보간 공식

```
일반 lerp:  pos = lerp(pos, target, 0.1)
문제: 프레임 레이트에 따라 속도가 달라짐

프레임 독립적: pos = lerp(pos, target, 1.0 - exp(-speed * delta))
이점: 60fps든 144fps든 같은 속도로 추적
```

**`exp(-speed * delta)`의 의미:**
- `speed`가 클수록 빠르게 따라감
- `delta`가 크면 (느린 프레임) 더 많이 이동하여 보상
- 수학적으로 지수적 감쇠(exponential decay)를 구현

---

## 6. 아이소메트릭 카메라 설정

### Transform3D 분석 (test_scene.tscn)

```ini
[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(
    0.707107, 0.353553, -0.612372,   # X축 방향 (기저 행 1)
    0, 0.866025, 0.5,                # Y축 방향 (기저 행 2)
    0.707107, -0.353553, 0.612372,   # Z축 방향 (기저 행 3)
    -6.12372, 5, 6.12372             # 위치
)
projection = 1    # 1 = Orthographic
size = 12.0       # 보이는 영역 크기 (세로 12 단위)
```

이 Transform은 **Ry(-45°) × Rx(-30°)** 회전을 나타냅니다:
- Y축 기준 -45° 회전 (대각선에서 바라봄)
- X축 기준 -30° 회전 (위에서 내려다봄)

```
  위에서 본 모습:          옆에서 본 모습:
      ╲                    카메라
       ╲ 45°                  ╲ 30°
        ╲                      ╲
    ─────●─────              ────●────
       (오브젝트)              (오브젝트)
```

이것이 전형적인 아이소메트릭(등축) 뷰입니다.

---

## 다음 단계

[04. 전투 시스템](04-combat-system.md)에서 공격, 데미지, HP 시스템을 살펴봅니다.
