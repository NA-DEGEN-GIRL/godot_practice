# 07. 이펙트와 렌더링

이 문서는 머티리얼, 조명, 파티클 시스템, 절차적 메시 생성을 설명합니다.

---

## 1. StandardMaterial3D

Godot에서 3D 오브젝트의 외형을 결정하는 가장 기본적인 머티리얼입니다.

### 기본 사용

```gdscript
var mat := StandardMaterial3D.new()
mat.albedo_color = Color(0.2, 0.4, 0.8, 1.0)  # 기본 색상 (RGBA)
```

### 이 프로젝트에서 사용하는 주요 속성

```gdscript
# 1. Unshaded: 조명의 영향을 받지 않음
mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
# 용도: HP바, 번개 이펙트 등 항상 일정한 밝기가 필요한 것

# 2. 투명도
mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
mat.albedo_color = Color(0.4, 0.6, 1.0, 0.3)  # A=0.3 → 70% 투명
# 용도: 번개 글로우, 파티클

# 3. 에미션 (자체 발광)
mat.emission_enabled = true
mat.emission = Color(1.0, 0.5, 0.1)
mat.emission_energy_multiplier = 2.0
# 용도: 번개 이펙트 (빛나는 느낌)

# 4. 빌보드 (항상 카메라를 향함)
mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
# 용도: 파티클 메시
```

### Shaded vs Unshaded 차이

```
Shaded (기본):               Unshaded:
  빛이 닿는 면은 밝고          모든 면이 동일한 색상
  반대쪽은 어두움               조명 무시
  그림자 영향 받음              그림자 무시
  ┌─┐                        ┌─┐
  │█│░                        │█│█
  └─┘                        └─┘
```

---

## 2. 조명 시스템

### DirectionalLight3D (태양광)

```ini
[node name="DirectionalLight3D" type="DirectionalLight3D"]
transform = Transform3D(0.866025, 0.353553, -0.353553, ...)
shadow_enabled = true
```

- 무한히 먼 곳에서 **평행한 빛**이 들어옴 (태양처럼)
- `shadow_enabled`: 그림자 활성화
- Transform의 회전이 빛의 방향을 결정

### OmniLight3D (점광원)

```gdscript
# 번개 이펙트의 플래시
var light := OmniLight3D.new()
light.light_color = Color(0.6, 0.8, 1.0, 1.0)  # 파란빛
light.light_energy = 5.0    # 밝기
light.omni_range = 6.0      # 영향 범위 (미터)
```

- 한 점에서 **모든 방향**으로 빛을 방출 (전구처럼)
- 번개가 칠 때 순간적으로 밝아지는 효과에 사용

### 환경 조명 (WorldEnvironment)

```ini
[sub_resource type="Environment" id="Environment_1"]
background_mode = 1                              # 단색 배경
background_color = Color(0.529, 0.706, 0.878, 1) # 하늘색
ambient_light_source = 2                          # 커스텀 앰비언트
ambient_light_color = Color(0.6, 0.65, 0.7, 1)   # 약간 푸른 앰비언트
ambient_light_energy = 0.5                        # 앰비언트 밝기
```

**앰비언트 라이트**: 모든 곳에 균일하게 비치는 간접 조명. 그림자 영역이 완전히 까맣지 않게 합니다.

---

## 3. GPUParticles3D (파티클 시스템)

화염방사기에서 사용하는 GPU 기반 파티클 시스템입니다.

### 구성 요소

```
GPUParticles3D
├── process_material (ParticleProcessMaterial) → 파티클의 행동 정의
└── draw_pass_1 (Mesh + Material) → 각 파티클의 외형 정의
```

### ParticleProcessMaterial 주요 속성

```gdscript
var mat := ParticleProcessMaterial.new()

# 방향과 퍼짐
mat.direction = Vector3(0, 0, -1)  # 기본 발사 방향
mat.spread = 20.0                   # 방향에서 ±20도 랜덤 퍼짐

# 속도
mat.initial_velocity_min = 6.0      # 최소 초기 속도 (m/s)
mat.initial_velocity_max = 8.0      # 최대 초기 속도

# 중력과 감속
mat.gravity = Vector3(0, 1.5, 0)    # 커스텀 중력 (위로 = 열기)
mat.damping_min = 1.0               # 감속 최소
mat.damping_max = 2.0               # 감속 최대

# 크기
mat.scale_min = 0.4
mat.scale_max = 1.0

# 발사 모양
mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
mat.emission_sphere_radius = 0.15   # 0.15m 반경 구에서 랜덤 발사
```

### 색상 그라데이션 (color_ramp)

파티클이 태어나서 죽을 때까지의 색상 변화:

```gdscript
var gradient := Gradient.new()
gradient.colors = PackedColorArray([
    Color(1.0, 0.95, 0.4, 0.9),   # t=0.0: 밝은 노랑, 거의 불투명
    Color(1.0, 0.55, 0.1, 0.8),   # t=0.3: 주황
    Color(0.9, 0.2, 0.0, 0.4),    # t=0.7: 어두운 빨강, 반투명
    Color(0.3, 0.1, 0.0, 0.0)     # t=1.0: 거의 검정, 완전 투명
])
gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
```

```
시간 →
t=0.0     t=0.3     t=0.7     t=1.0
🟡 밝은노랑 → 🟠 주황 → 🔴 어두운빨강 → ⚫ 투명
(탄생)                                    (소멸)
```

### 파티클 메시

각 파티클이 화면에 어떻게 그려지는지:

```gdscript
var quad := QuadMesh.new()         # 사각형 면
quad.size = Vector2(0.4, 0.4)     # 40cm x 40cm

var quad_mat := StandardMaterial3D.new()
quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED    # 조명 무시
quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA        # 투명도 사용
quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED       # 카메라 향함
quad_mat.vertex_color_use_as_albedo = true  # ★ ParticleProcessMaterial의 색상 사용

quad.material = quad_mat
particles.draw_pass_1 = quad
```

**`vertex_color_use_as_albedo`**: ParticleProcessMaterial이 각 파티클에 부여하는 색상(color_ramp에서 계산)을 메시의 기본 색상으로 사용합니다. 이걸 `true`로 안 하면 파티클이 모두 흰색으로 나옵니다.

### GPUParticles3D 속성

```gdscript
particles.amount = 64           # 최대 파티클 수
particles.lifetime = 0.5        # 각 파티클 수명 (초)
particles.emitting = true       # 파티클 생성 활성화
particles.visibility_aabb = AABB(...)  # 컬링 영역 (이 밖으로 나가면 안 보임)
```

**visibility_aabb**: GPU 파티클은 화면 밖에 있으면 자동으로 컬링(렌더링 건너뜀)됩니다. 하지만 파티클이 원점에서 멀리 날아가면 AABB 밖으로 나가서 사라질 수 있으므로 충분히 크게 설정합니다.

---

## 4. ImmediateMesh (절차적 메시)

번개 이펙트에서 사용하는 코드 기반 메시 생성입니다.

### 일반 Mesh vs ImmediateMesh

```
일반 Mesh (BoxMesh, CapsuleMesh):
  - 미리 정의된 모양
  - 에디터에서 속성 조절 가능
  - 런타임에 모양 변경 어려움

ImmediateMesh:
  - 코드에서 꼭짓점을 직접 찍어서 만듦
  - 매번 다른 모양 가능 (절차적)
  - 번개처럼 랜덤한 모양에 적합
```

### Triangle Strip 이해

```
번호 = 꼭짓점 순서

1───3───5───7
│ ╲ │ ╲ │ ╲ │    PRIMITIVE_TRIANGLE_STRIP
2───4───6───8

생성되는 삼각형:
(1,2,3), (2,3,4), (3,4,5), (4,5,6), (5,6,7), (6,7,8)
```

**장점**: N개의 꼭짓점으로 N-2개의 삼각형 생성 (효율적)

### 번개에 적용

```gdscript
im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
for p in points:  # 지그재그 점들을 순서대로
    im.surface_add_vertex(Vector3(p.x - width, p.y, p.z))  # 왼쪽
    im.surface_add_vertex(Vector3(p.x + width, p.y, p.z))  # 오른쪽
im.surface_end()
```

```
각 점(p)에서 좌우로 width만큼 확장:

    ←w→
    1─2        ← points[0]
    │╲│
    3─4        ← points[1] (지그재그)
    │╲│
    5─6        ← points[2]
    │╲│
    7─8        ← points[3]

결과: 지그재그 경로를 따라 "리본"이 만들어짐
```

---

## 5. Label3D (3D 텍스트)

데미지 숫자와 HP 텍스트에 사용됩니다.

### 주요 속성

```gdscript
var label := Label3D.new()
label.text = "42!"
label.font_size = 48                                    # 폰트 크기
label.pixel_size = 0.005                                # 1픽셀 = 0.005 3D 단위
label.billboard = BaseMaterial3D.BILLBOARD_ENABLED      # 항상 카메라 향함
label.no_depth_test = true                              # 다른 물체에 가려지지 않음
label.render_priority = 10                              # 렌더링 우선순위
label.outline_size = 8                                  # 외곽선 두께
label.outline_modulate = Color(0, 0, 0, 0.8)           # 외곽선 색상
label.modulate = Color(1.0, 0.9, 0.2, 1.0)            # 텍스트 색상
```

**`pixel_size`**: 3D 공간에서 1픽셀이 차지하는 크기. `font_size=48, pixel_size=0.005`이면 텍스트 높이 ≈ `48 × 0.005 = 0.24` 3D 단위.

**`no_depth_test`**: 깊이 테스트를 무시하면 다른 오브젝트 뒤에 있어도 항상 보입니다. 데미지 숫자가 캐릭터 몸에 가려지면 안 되므로 사용합니다.

---

## 6. 총알 이펙트 (player.gd)

### 총알 트레이서 (Bullet Tracer)

발사 시 총구에서 착탄 지점까지 빛나는 총알이 날아갑니다:

```gdscript
func _spawn_bullet_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
    # 1. 빛나는 총알 머리 (작은 구)
    var bullet := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.05
    bullet.mesh = sphere
    var bullet_mat := StandardMaterial3D.new()
    bullet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bullet_mat.albedo_color = Color(1.0, 1.0, 0.7, 1.0)
    bullet_mat.emission_enabled = true
    bullet_mat.emission = Color(1.0, 0.9, 0.5)
    bullet_mat.emission_energy_multiplier = 6.0   # 강한 발광
    bullet.material_override = bullet_mat
```

**`emission_energy_multiplier`**: 값이 클수록 더 밝게 빛납니다. 1.0이 기본이고, 6.0이면 매우 강한 글로우.

```gdscript
    # 2. 따라다니는 파티클 꼬리
    var trail := GPUParticles3D.new()
    trail.amount = 20
    trail.lifetime = 0.15
    # ...주황색 작은 구 파티클...
    bullet.add_child(trail)   # ★ 총알의 자식 → 총알과 함께 이동

    # 3. 총알 비행 애니메이션 (Tween)
    var dist := from_pos.distance_to(to_pos)
    var flight_time := clampf(dist / 20.0, 0.15, 0.5)  # 거리에 비례
    var tween := bullet.create_tween()
    tween.tween_property(bullet, "global_position", to_pos, flight_time)
    tween.tween_callback(func():
        _spawn_impact_sparks(to_pos)     # 착탄 스파크
        trail.emitting = false            # 파티클 새로 안 만듦
        bullet.visible = false            # 총알 숨김
        get_tree().create_timer(0.3).timeout.connect(bullet.queue_free)
    )
```

**왜 즉시 `queue_free()`하지 않는가?**

파티클이 이미 생성된 것들은 `emitting = false` 후에도 lifetime 동안 계속 보입니다. 바로 삭제하면 꼬리가 갑자기 사라집니다. 0.3초 기다린 후 삭제하면 자연스럽게 사라집니다.

```gdscript
    # 4. 직선 스트릭 라인 (잔상)
    var streak := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.02, 0.02, streak_len)   # 매우 얇은 직사각형
    streak.mesh = box
    # ...노란 발광 머티리얼...
    streak.look_at(to_pos, Vector3.UP)             # 타겟 방향으로 회전

    var streak_tween := streak.create_tween()
    streak_tween.tween_property(streak_mat, "albedo_color:a", 0.0, 0.35)  # 0.35초간 페이드아웃
    streak_tween.tween_callback(streak.queue_free)
```

**`look_at(target, up)`**: 메시를 target 방향으로 정렬합니다. 얇은 직사각형이 총알 경로를 따라 배치되어 레이저 같은 잔상이 됩니다.

### 머즐 플래시 (Muzzle Flash)

```gdscript
func _spawn_muzzle_flash(pos: Vector3) -> void:
    # 파티클 버스트 (방사형 불꽃)
    var flash := GPUParticles3D.new()
    flash.one_shot = true          # ★ 한 번만 발사
    flash.amount = 15
    flash.lifetime = 0.15          # 아주 짧은 수명
    flash.explosiveness = 1.0      # ★ 모든 파티클이 동시에 발사
    var fmat := ParticleProcessMaterial.new()
    fmat.direction = Vector3(sin(_facing_angle), 0.3, cos(_facing_angle))  # 총구 방향
    fmat.spread = 25.0             # ±25도 퍼짐

    # 밝은 코어 (구형 빛)
    var core := MeshInstance3D.new()
    # ...밝은 흰노랑 발광 구...
    tween.tween_property(core, "scale", Vector3(2.0, 2.0, 2.0), 0.06)  # 빠르게 확대
    tween.parallel().tween_property(core_mat, "albedo_color:a", 0.0, 0.1)  # 빠르게 사라짐
```

**`explosiveness = 1.0`**: 기본값(0.0)은 파티클이 lifetime 동안 균일하게 생성됩니다. 1.0이면 모든 파티클이 한꺼번에 생성 → 폭발/플래시 효과.

**`one_shot = true`**: 파티클이 한 번만 발사되고 다시 생성되지 않습니다.

### 착탄 스파크 (Impact Sparks)

```gdscript
func _spawn_impact_sparks(pos: Vector3) -> void:
    # 스파크 (위로 튀어오르는 불꽃)
    var sparks := GPUParticles3D.new()
    sparks.one_shot = true
    sparks.amount = 20
    var pmat := ParticleProcessMaterial.new()
    pmat.direction = Vector3(0, 1, 0)        # 위쪽으로
    pmat.spread = 60.0                        # 넓게 퍼짐
    pmat.initial_velocity_min = 3.0
    pmat.initial_velocity_max = 7.0
    pmat.gravity = Vector3(0, -12, 0)         # 중력으로 포물선 낙하
    pmat.color = Color(1.0, 0.7, 0.1, 1.0)   # 주황색

    # 연기 (천천히 피어오르는 회색)
    var smoke := GPUParticles3D.new()
    smat.initial_velocity_max = 1.5
    smat.gravity = Vector3(0, 0.5, 0)         # 약간 위로 (열기)
    smat.color = Color(0.5, 0.5, 0.5, 0.4)   # 반투명 회색
```

### 총알 이펙트 조합 시각화

```
발사 시:
  [머즐 플래시]    [총알 트레이서 ──────→]    [착탄 스파크]
  ★☆★             ● ══════════════>           ✦✦✦
  (0.1초)          (0.15~0.5초)                (0.4초)
                   + 직선 스트릭 라인           + 연기
                   (0.35초 페이드아웃)          (0.5초)
```

---

## 7. 렌더링 팁 요약

| 기법 | 용도 | 설명 |
|------|------|------|
| Unshaded | HP바, 이펙트 | 조명 무시, 항상 같은 밝기 |
| TRANSPARENCY_ALPHA | 이펙트 | RGBA의 A값으로 투명도 제어 |
| Billboard | 파티클, Label3D | 항상 카메라를 정면으로 향함 |
| Emission | 번개 이펙트 | 자체 발광, 글로우 효과 |
| vertex_color_use_as_albedo | 파티클 메시 | 파티클 시스템의 색상을 메시에 적용 |
| no_depth_test | 데미지 숫자 | 다른 물체에 가려지지 않음 |
| render_priority | 데미지 숫자 | 렌더링 순서 제어 |

---

## 다음 단계

[08. 오디오](08-audio.md)에서 사운드 재생과 루프를 살펴봅니다.
