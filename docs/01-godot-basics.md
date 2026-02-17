# 01. Godot 기초 개념

이 문서는 Godot 엔진을 처음 접하는 사람을 위한 핵심 개념 설명입니다. 이 프로젝트의 코드를 이해하는 데 필요한 기초를 다룹니다.

---

## 1. 씬(Scene)과 노드(Node)

Godot의 가장 핵심적인 개념은 **씬**과 **노드**입니다.

### 노드(Node)란?

노드는 Godot의 기본 빌딩 블록입니다. 게임의 모든 것(캐릭터, 카메라, 빛, UI 등)은 노드입니다.

```
Node              ← 최상위 기본 노드
├── Node2D        ← 2D 게임 오브젝트
├── Node3D        ← 3D 게임 오브젝트
├── Control       ← UI 요소
├── Camera3D      ← 3D 카메라
├── MeshInstance3D ← 3D 메시(모양)를 화면에 그리는 노드
├── StaticBody3D  ← 움직이지 않는 물리 바디
├── CharacterBody3D ← 캐릭터용 물리 바디
├── RigidBody3D   ← 물리 시뮬레이션되는 바디
└── ...수백 가지
```

### 씬(Scene)이란?

씬은 노드들의 **트리(나무) 구조**입니다. `.tscn` 파일로 저장됩니다.

```
예: player.tscn의 구조

Player (CharacterBody3D)     ← 루트 노드
├── MeshInstance3D           ← 캐릭터 외형 (파란 캡슐)
└── CollisionShape3D         ← 충돌 영역
```

**핵심 포인트:**
- 씬은 다른 씬 안에 **인스턴스(instance)**로 넣을 수 있습니다
- 이것이 Godot의 "합성(composition)" 패턴입니다
- 예: `test_scene.tscn` 안에 `player.tscn`과 `enemy.tscn`이 인스턴스로 들어가 있습니다

### .tscn 파일 구조

`.tscn` 파일은 텍스트 형식입니다. 직접 열어볼 수 있습니다:

```ini
[gd_scene load_steps=5 format=3]

; 외부 리소스 참조 (다른 파일에서 가져옴)
[ext_resource type="Script" path="res://player.gd" id="1"]

; 내부 리소스 (이 씬 안에서 정의)
[sub_resource type="CapsuleMesh" id="CapsuleMesh_1"]

; 노드 정의
[node name="Player" type="CharacterBody3D"]
script = ExtResource("1")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
mesh = SubResource("CapsuleMesh_1")
```

- `ext_resource`: 외부 파일 참조 (스크립트, 다른 씬 등)
- `sub_resource`: 씬 내부에 정의된 리소스
- `[node ...]`: 노드 정의. `parent="."` 은 루트 노드의 자식이라는 뜻

---

## 2. GDScript 기초

GDScript는 Godot 전용 스크립팅 언어입니다. Python과 매우 비슷합니다.

### 기본 문법

```gdscript
# 변수 선언
var speed: float = 5.0          # 타입 명시
var name := "Player"            # 타입 추론 (:= 사용)
var target: Vector3              # 타입만 명시, 초기값 없음

# 상수
const MAX_HP := 100.0

# Export: 에디터 인스펙터에서 값을 조절할 수 있게 노출
@export var move_speed: float = 5.0

# @onready: 씬이 준비된 후에 노드 참조를 가져옴
@onready var mesh: MeshInstance3D = $MeshInstance3D
```

### 핵심 함수들

```gdscript
extends CharacterBody3D  # 이 스크립트가 어떤 노드 타입을 확장하는지

# 노드가 씬 트리에 추가될 때 한 번 호출
func _ready() -> void:
    pass

# 매 프레임 호출 (렌더링 프레임)
func _process(delta: float) -> void:
    # delta = 이전 프레임 이후 경과 시간 (초)
    pass

# 매 물리 프레임 호출 (기본 60fps 고정)
func _physics_process(delta: float) -> void:
    # 물리 관련 로직은 여기서
    pass

# 입력 이벤트 처리 (다른 곳에서 처리하지 않은 입력)
func _unhandled_input(event: InputEvent) -> void:
    pass
```

### $ 연산자 (노드 경로 접근)

```gdscript
# $ 는 get_node()의 축약형
$MeshInstance3D          # = get_node("MeshInstance3D")
$HPBar/Fill              # = get_node("HPBar/Fill") (자식의 자식)
$"../Player"             # = get_node("../Player") (부모의 다른 자식)
```

### 타입 시스템

```gdscript
# 기본 타입
var i: int = 10
var f: float = 3.14
var s: String = "hello"
var b: bool = true

# Godot 수학 타입
var v2: Vector2 = Vector2(1.0, 2.0)        # 2D 좌표/방향
var v3: Vector3 = Vector3(1.0, 2.0, 3.0)  # 3D 좌표/방향
var c: Color = Color(1.0, 0.5, 0.0, 1.0)  # RGBA 색상

# 컬렉션
var arr: Array = [1, 2, 3]
var typed_arr: Array[float] = [1.0, 2.0]
var dict: Dictionary = {"key": "value"}
```

---

## 3. 씬 트리(Scene Tree)와 노드 생명주기

### 씬 트리

실행 중인 게임의 모든 노드는 하나의 큰 트리를 형성합니다:

```
SceneTree (루트)
└── TestScene (Node3D)          ← 메인 씬
    ├── WorldEnvironment
    ├── Camera3D
    ├── DirectionalLight3D
    ├── Ground (StaticBody3D)
    │   ├── MeshInstance3D
    │   └── CollisionShape3D
    ├── Player (CharacterBody3D) ← player.tscn 인스턴스
    │   ├── MeshInstance3D
    │   └── CollisionShape3D
    ├── Enemy (StaticBody3D)     ← enemy.tscn 인스턴스
    │   ├── MeshInstance3D
    │   ├── CollisionShape3D
    │   └── HPBar (Node3D)
    └── SkillBar (CanvasLayer)
```

### 노드 생명주기

```
1. _init()          → 노드 객체 생성 (잘 안 씀)
2. _enter_tree()    → 씬 트리에 추가됨
3. _ready()         → 모든 자식 노드도 준비 완료 ★ 가장 많이 사용
4. _process()       → 매 프레임 반복 호출
5. _physics_process() → 매 물리 프레임 반복 호출
6. _exit_tree()     → 씬 트리에서 제거됨
```

### 노드를 코드로 생성하기

```gdscript
# 새 노드 생성
var label := Label3D.new()
label.text = "Hello"
label.position = Vector3(0, 2, 0)

# 씬 트리에 추가 (자식으로)
add_child(label)

# 씬 트리에서 제거 + 메모리 해제
label.queue_free()
```

### 씬 인스턴싱

```gdscript
# 씬 파일을 미리 로드 (컴파일 시점에 로드)
var scene: PackedScene = preload("res://lightning_effect.tscn")

# 씬을 인스턴스화 (복제본 생성)
var instance := scene.instantiate()
instance.global_position = Vector3(0, 0, 0)

# 현재 씬에 추가
get_tree().current_scene.add_child(instance)
```

---

## 4. 시그널(Signal)

시그널은 Godot의 **옵저버 패턴** 구현입니다. 노드 간 통신에 사용합니다.

```gdscript
# 내장 시그널 연결
var timer := get_tree().create_timer(3.0)
timer.timeout.connect(_on_timeout)  # 3초 후 _on_timeout 호출

func _on_timeout() -> void:
    print("3초 지남!")

# AudioStreamPlayer의 finished 시그널
_sfx_fire.finished.connect(_on_fire_sfx_finished)

func _on_fire_sfx_finished() -> void:
    if _flamethrower_active:
        _sfx_fire.play()  # 사운드 끝나면 다시 재생
```

**이 프로젝트에서 시그널이 사용되는 곳:**
- 적 리스폰 타이머: `create_timer().timeout.connect(_respawn)`
- 화염 사운드 루프: `_sfx_fire.finished.connect(_on_fire_sfx_finished)`
- Tween 완료 콜백: `tween.tween_callback(queue_free)`

---

## 5. 리소스(Resource)

리소스는 재사용 가능한 데이터 컨테이너입니다.

```gdscript
# 메시 (3D 모양)
var mesh := CapsuleMesh.new()       # 캡슐
var mesh := BoxMesh.new()           # 박스
var mesh := QuadMesh.new()          # 사각형 판

# 머티리얼 (외형/재질)
var mat := StandardMaterial3D.new()
mat.albedo_color = Color(0.2, 0.4, 0.8)  # 색상
mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # 조명 무시

# 물리 모양
var shape := CapsuleShape3D.new()
var shape := BoxShape3D.new()

# 오디오
var stream: AudioStreamWAV = preload("res://sounds/bolt.wav")
```

---

## 6. 좌표계와 Transform

### Godot 3D 좌표계

```
    Y (위)
    |
    |
    +------ X (오른쪽)
   /
  Z (카메라 쪽, 앞)
```

- **Y축이 위**: 2D와 달리 Y가 위를 가리킵니다
- **-Z가 "앞"**: 노드의 기본 전방 방향은 -Z입니다
- 오른손 좌표계입니다

### Transform3D

노드의 위치, 회전, 크기를 나타냅니다:

```gdscript
# 위치 설정
node.position = Vector3(3, 0, -1)          # 로컬 좌표
node.global_position = Vector3(3, 0, -1)   # 월드 좌표

# 회전 (라디안)
node.rotation.y = PI / 4  # Y축 기준 45도 회전

# .tscn 파일에서의 Transform3D:
# Transform3D(기저행렬 9개값, 위치 3개값)
# Transform3D(xx,xy,xz, yx,yy,yz, zx,zy,zz, tx,ty,tz)
transform = Transform3D(1, 0, 0,  0, 1, 0,  0, 0, 1,  0, 1, 0)
#                       └ 기저(회전/스케일) ┘  └ 위치 ┘
# 이 경우: 회전 없음(단위 행렬), 위치 (0, 1, 0)
```

---

## 7. 물리 바디 타입

이 프로젝트에서 사용하는 3가지 물리 바디:

| 타입 | 용도 | 특징 |
|------|------|------|
| `StaticBody3D` | 지형, 벽, 적 | 움직이지 않음. 다른 것이 부딪힐 수 있음 |
| `CharacterBody3D` | 플레이어 | 코드로 직접 이동. `move_and_slide()` 사용 |
| `RigidBody3D` | 밀 수 있는 상자 | 물리 엔진이 시뮬레이션. 힘/충격으로 이동 |

```gdscript
# CharacterBody3D 이동 패턴
velocity = direction * speed  # 속도 설정
move_and_slide()               # 충돌 처리하며 이동

# RigidBody3D에 힘 가하기
rigid_body.apply_central_impulse(push_direction * force)
```

---

## 8. Tween (애니메이션)

Tween은 코드에서 값을 부드럽게 변화시키는 도구입니다:

```gdscript
var tween := create_tween()

# 속성을 0.5초에 걸쳐 변경
tween.tween_property(node, "position:y", 5.0, 0.5)

# 동시에 실행 (parallel)
tween.parallel().tween_property(node, "modulate:a", 0.0, 0.5)

# 순차 실행 (기본)
tween.tween_property(light, "light_energy", 0.0, 0.25)

# 완료 후 콜백
tween.tween_callback(queue_free)  # 노드 삭제

# 대기
tween.tween_interval(0.6)  # 0.6초 대기

# 이징 (가속/감속)
tween.set_ease(Tween.EASE_OUT)
tween.set_trans(Tween.TRANS_CUBIC)
```

**이 프로젝트에서 Tween 사용 예:**
- 번개 이펙트: 빛 깜박임 → 페이드아웃 → 삭제
- 데미지 숫자: 위로 떠오르며 투명해짐 → 삭제
- 크리티컬: 큰 스케일에서 원래 크기로 축소

---

## 9. 그룹(Group)

노드에 태그를 붙여서 카테고리화하는 기능입니다:

```gdscript
# 그룹에 추가
add_to_group("enemy")

# 그룹 체크
if node.is_in_group("enemy"):
    node.take_damage(10.0)

# 그룹의 모든 노드 가져오기
var enemies := get_tree().get_nodes_in_group("enemy")
```

이 프로젝트에서 적(`enemy.gd`)은 `_ready()`에서 `"enemy"` 그룹에 자신을 추가합니다. 플레이어는 이 그룹을 체크해서 공격 대상을 식별합니다.

---

## 10. 자주 쓰는 유틸리티

```gdscript
# 랜덤
randf()                          # 0.0 ~ 1.0 랜덤 실수
randf_range(-5.0, 5.0)          # 범위 내 랜덤 실수
randi_range(1, 10)              # 범위 내 랜덤 정수

# 수학
clampf(value, 0.0, 1.0)        # 값을 범위 내로 제한
maxf(a, b)                      # 둘 중 큰 값
lerpf(a, b, 0.5)               # 선형 보간 (a와 b의 중간값)
Vector3.lerp(a, b, t)          # 벡터 선형 보간

# 거리
pos_a.distance_to(pos_b)       # 두 점 사이 거리

# 시간
delta                            # 프레임 간 경과 시간 (초)
# 60fps → delta ≈ 0.0167
# 속도 * delta = 프레임 독립적 이동
```

---

## 다음 단계

이 기초 개념을 이해했다면, [02. 프로젝트 아키텍처](02-project-architecture.md)에서 이 프로젝트의 전체 구조를 살펴보세요.
