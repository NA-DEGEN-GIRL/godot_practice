# 11. 적 AI 시스템

이 문서는 네 종류 적의 AI 행동 패턴, 애니메이션 상태 머신, 공격 시스템을 설명합니다.

---

## 1. 적 종류 비교

| | Enemy (독) | Enemy2 (근접) | Enemy3 (감전) | Enemy4 (게으른 돌진) |
|---|---|---|---|---|
| **파일** | `enemy.gd` | `enemy2.gd` | `enemy3.gd` | `enemy4.gd` |
| **모델** | `enemy_rigging_textured_fixed.glb` | `enemy2_rigging_textured_3motions.glb` | `enemy3.glb` | `enemy4.glb` |
| **HP** | 100 | 120 | 100 | 180 |
| **공격 방식** | 독 투사체 (원거리) | 주먹 (근접) | 잽 (근접, 약함) | 돌진 구르기 (강력) |
| **공격 데미지** | 8 | 15 | 8 | 65 (~HP의 1/3) |
| **공격 사거리** | 3.0 | 1.8 | 1.8 | 1.2 |
| **이동 패턴** | 감지 시 추격만 | 배회 + 추격 | 배회 + 추격 | 배회 ↔ 수면 + 돌진 |
| **애니메이션** | 1개 | 3개 | 4개 (감전 포함) | 4개 (수면 포함) |
| **사운드** | 독 뱉기 | 좀비 그로울 | 공격 사운드 + 감전 | 지진 공격 |
| **특수 기능** | - | - | 번개 맞으면 3초 스턴 | 수면/기상 사이클 |
| **HP바 색** | 빨간색 | 빨간색 | 보라색 | 주황색 |

---

## 2. Enemy2 상태 머신

Enemy2는 3가지 상태를 가집니다:

```
                    ┌─────────┐
                    │ WANDER  │ ← 기본 상태
                    │ (배회)   │
                    └────┬────┘
                         │ 플레이어 감지 (7m 이내)
                         ▼
                    ┌─────────┐
                    │  CHASE  │
                    │ (추격)   │
                    └────┬────┘
                         │ 사정거리 도달 (1.8m 이내)
                         ▼
                    ┌─────────┐
                    │ ATTACK  │
                    │ (공격)   │
                    └─────────┘

* 플레이어가 7m 밖으로 나가면 → WANDER로 복귀
* 사정거리 밖으로 벗어나면 → CHASE로 복귀
```

### 상태 결정 코드

```gdscript
func _physics_process(delta: float) -> void:
    # ...

    var state := "wander"  # 기본 상태

    if _target and is_instance_valid(_target) and not _target.is_dead:
        var to_target := _target.global_position - global_position
        to_target.y = 0.0
        var dist := to_target.length()

        if dist < detect_range:        # 7m 이내
            if dist <= attack_range:   # 1.8m 이내
                state = "attack"
            else:
                state = "chase"

    match state:
        "chase":  _do_chase(delta)
        "attack": _do_attack(delta)
        "wander": _do_wander(delta)
```

**`match` 문법**: GDScript의 패턴 매칭. Python의 `match/case`와 유사합니다:

```gdscript
match state:
    "chase":  _do_chase(delta)    # state == "chase"이면 실행
    "attack": _do_attack(delta)
    "wander": _do_wander(delta)
```

---

## 3. 배회 (Wander) 상태

적이 플레이어를 감지하지 못했을 때 맵을 슬금슬금 돌아다닙니다.

### 배회 흐름

```
1. 랜덤 목표 지점 선택 → _pick_wander_target()
2. 목표까지 walking 모션으로 이동
3. 도착하면 1~3초 대기
4. 다시 새 목표 선택 → 반복
```

### 코드

```gdscript
func _do_wander(delta: float) -> void:
    _wander_timer -= delta
    if _wander_timer <= 0.0:
        if _wander_wait > 0.0:
            # 대기 단계: 가만히 서 있기
            _wander_wait -= delta
            velocity.x = 0.0
            velocity.z = 0.0
            return
        _pick_wander_target()  # 새 목표 지점

    var diff := _wander_target - global_position
    diff.y = 0.0
    if diff.length() < 0.5:
        # 목표 도착 → 대기 모드
        _wander_wait = randf_range(1.0, 3.0)
        _wander_timer = 0.0
        return

    var dir := diff.normalized()
    velocity.x = dir.x * move_speed       # 느린 속도 (1.5)
    velocity.z = dir.z * move_speed
    _face_direction(dir)                    # 이동 방향 바라보기
    _play_anim(_anim_walk)                  # walking 애니메이션

func _pick_wander_target() -> void:
    _wander_target = Vector3(
        randf_range(-8.0, 8.0),
        0,
        randf_range(-8.0, 8.0)
    )
    _wander_timer = randf_range(3.0, 6.0)  # 3~6초 동안 이동
```

---

## 4. 추격 (Chase) 상태

플레이어가 감지 범위(7m) 안에 들어오면 달려서 쫓아옵니다.

```gdscript
func _do_chase(_delta: float) -> void:
    var to_target := _target.global_position - global_position
    to_target.y = 0.0
    var dir := to_target.normalized()
    velocity.x = dir.x * run_speed       # 빠른 속도 (4.5)
    velocity.z = dir.z * run_speed
    _face_direction(dir)                   # 플레이어 바라보기
    _play_anim(_anim_run)                  # running 애니메이션
```

**배회 vs 추격 속도 차이:**

```
배회: move_speed = 1.5  (천천히 돌아다님)
추격: run_speed  = 4.5  (3배 빠르게 쫓아옴)
```

---

## 5. 공격 (Attack) 상태

사정거리(1.8m) 안에 들어오면 주먹 공격을 합니다.

### 공격 흐름

```
1. 정지 + 플레이어 방향 바라보기
2. 쿨타임 확인 (2초)
3. 좀비 소리 + jab 애니메이션 시작
4. _is_attacking_anim = true (이동 차단)
5. 애니메이션 끝 → animation_finished 시그널
6. 판정: 플레이어가 아직 사정거리 안이면 데미지
7. 사정거리 밖이면 미스 (회피 성공!)
```

### 공격 개시 코드

```gdscript
func _do_attack(_delta: float) -> void:
    velocity.x = 0.0
    velocity.z = 0.0

    # 플레이어 바라보기
    var to_target := _target.global_position - global_position
    to_target.y = 0.0
    if to_target.length_squared() > 0.001:
        _face_direction(to_target.normalized())

    if _attack_timer <= 0.0 and _anim_attack != "":
        _attack_timer = attack_cooldown    # 2초 쿨다운
        _is_attacking_anim = true          # ★ 이동 차단 플래그
        _sfx_attack.pitch_scale = randf_range(0.8, 1.2)  # 약간 다른 음높이
        _sfx_attack.play()
        if _anim_player:
            _anim_player.stop()
            _anim_player.play(_anim_attack)
```

### 데미지 판정 (애니메이션 끝에서)

```gdscript
func _on_animation_finished(anim_name: String) -> void:
    if _is_attacking_anim:
        _is_attacking_anim = false
        # ★ 핵심: 공격 애니메이션이 끝난 시점에 거리 체크
        if _target and is_instance_valid(_target) and not _target.is_dead:
            var dist := global_position.distance_to(_target.global_position)
            if dist <= attack_range + 0.3:           # 약간의 여유 (1.8 + 0.3)
                _target.take_damage(attack_damage)   # 맞음!
            # else: 플레이어가 이미 도망감 → 미스
```

**`_is_attacking_anim` 플래그의 역할:**

```gdscript
# _physics_process 상단에서
if _is_attacking_anim:
    velocity.x = 0.0
    velocity.z = 0.0
    move_and_slide()
    return           # ★ 상태 판정 건너뜀 → 공격 중에는 이동/추격 안 함
```

**왜 애니메이션 끝에서 판정하는가?**

실제 격투 게임에서도 "주먹이 닿는 순간"에 판정합니다. 애니메이션이 시작될 때 즉시 데미지를 주면, 플레이어가 반응할 시간이 없습니다. 끝에서 판정하면:
- 플레이어는 공격 모션을 보고 도망칠 수 있음 (회피 가능)
- 공격이 빗나가는 재미 요소 추가

---

## 6. 애니메이션 시스템

### 자동 애니메이션 감지

GLB 모델의 애니메이션 이름은 모델마다 다를 수 있으므로, 이름 패턴 매칭으로 자동 감지합니다:

```gdscript
func _detect_animations() -> void:
    var anims := _anim_player.get_animation_list()  # ["Walking", "Running", "RightJab"]
    for a in anims:
        var lower := a.to_lower()
        if "walk" in lower:
            _anim_walk = a          # "Walking"
        elif "run" in lower:
            _anim_run = a           # "Running"
        elif "jab" in lower or "attack" in lower or "punch" in lower:
            _anim_attack = a        # "RightJab"
```

### 애니메이션 재생과 반복

```gdscript
func _play_anim(anim_name: String) -> void:
    if not _anim_player or anim_name == "" or _is_attacking_anim:
        return
    # ★ 같은 애니메이션이 끝났을 때도 다시 재생 (루프 효과)
    if _current_anim != anim_name or not _anim_player.is_playing():
        _anim_player.play(anim_name)
        _current_anim = anim_name
        if anim_name == _anim_run:
            _anim_player.speed_scale = 1.5   # 달리기 1.5배속
        else:
            _anim_player.speed_scale = 1.0
```

**`not _anim_player.is_playing()` 체크가 필요한 이유:**

GLB에서 가져온 애니메이션은 기본적으로 루프 설정이 안 되어 있을 수 있습니다. 애니메이션이 끝나면 `_current_anim`은 여전히 같은 이름이지만 `is_playing()`이 `false`가 됩니다. 이 체크가 없으면 애니메이션이 한 번만 재생되고 멈춥니다.

---

## 7. 방향 전환 (look_at)

```gdscript
func _face_direction(dir: Vector3) -> void:
    if _model and dir.length_squared() > 0.001:
        _model.look_at(global_position - dir, Vector3.UP)
```

**왜 `global_position - dir`인가?**

`look_at(target, up)`은 노드가 `target` 위치를 **바라보게** 합니다. 우리는 `dir` 방향으로 **이동하는 쪽**을 바라보게 하고 싶습니다:

```
# dir = 이동 방향 (플레이어 쪽)
# global_position + dir = 앞쪽     ← look_at으로 바라볼 곳
# global_position - dir = 뒤쪽

# 모델이 -Z를 앞으로 보는 경우 (Godot 규칙):
# look_at(앞쪽)으로 하면 뒤를 향함
# look_at(뒤쪽)으로 하면 앞을 향함 ← 올바름
```

3D 모델의 "앞"이 -Z 방향인 Godot의 관례 때문에 반대 방향을 바라보게 합니다.

---

## 8. Enemy (독 공격) - 기존 적

기존 적은 더 단순한 AI입니다:

### 행동 패턴

```
감지 범위 밖 → 정지 (가만히 서 있음)
감지 범위 안 → 플레이어에게 접근
공격 범위 안 → 독 투사체 발사
```

### 독 투사체 (회피 가능!)

```gdscript
func _spit_poison(target: Node3D) -> void:
    var start_pos := global_position + Vector3(0, 1.2, 0)
    var end_pos := target.global_position + Vector3(0, 1.0, 0)  # ★ 현재 위치 기준

    # 독 구체 생성
    var ball := MeshInstance3D.new()
    # ...초록색 발광 구체...

    # ★ 포물선 비행 (플레이어의 "현재" 위치로, 추적 안 함)
    var mid := (start_pos + end_pos) / 2.0 + Vector3(0, 1.0, 0)
    tween.tween_method(func(t: float):
        var p1 := start_pos.lerp(mid, t)
        var p2 := mid.lerp(end_pos, t)
        ball.global_position = p1.lerp(p2, t)    # 베지어 곡선
    , 0.0, 1.0, flight_time)

    tween.tween_callback(func():
        # ★ 착탄 판정: 도착 시점에 플레이어가 근처에 있는지
        var dist_to_impact := target.global_position.distance_to(impact_pos)
        if dist_to_impact <= hit_radius:     # 0.8m 이내
            target.take_damage(attack_damage)
        _spawn_poison_splash(impact_pos)
    )
```

**회피 메커니즘:**
1. 독 투사체는 발사 시점의 플레이어 위치를 향해 날아감 (유도 안 함)
2. 비행 시간 동안 플레이어가 이동하면 빗나감
3. 착탄 지점에서 0.8m 반경 판정

---

## 9. 사망과 리스폰

두 종류의 적 모두 동일한 패턴을 사용합니다:

```gdscript
func _die() -> void:
    is_alive = false
    visible = false
    $CollisionShape3D.disabled = true
    get_tree().create_timer(randf_range(3.0, 8.0)).timeout.connect(_respawn)

func _respawn() -> void:
    current_hp = max_hp
    _update_hp_bar()
    global_position = _find_clear_position()  # 다른 물체와 안 겹치는 위치
    is_alive = true
    visible = true
    $CollisionShape3D.disabled = false
    _is_attacking_anim = false       # Enemy2만: 공격 플래그 리셋
    _current_anim = ""               # Enemy2만: 애니메이션 리셋
    _pick_wander_target()            # Enemy2만: 새 배회 경로
```

---

## 10. pitch_scale로 사운드 변형

같은 효과음을 매번 다르게 들리게 하는 테크닉:

```gdscript
_sfx_attack.pitch_scale = randf_range(0.8, 1.2)
_sfx_attack.play()
```

- `pitch_scale = 1.0`: 원래 속도/음높이
- `pitch_scale = 0.8`: 느리고 낮은 소리
- `pitch_scale = 1.2`: 빠르고 높은 소리

매 공격마다 0.8~1.2 사이 랜덤 값을 사용하면, 하나의 WAV 파일로도 다양하게 들립니다. 게임에서 흔히 사용하는 기법입니다.

---

## 11. Enemy3 - 감전 스턴 적

### 특징

Enemy2와 비슷한 배회/추격/공격 AI이지만, **번개 스킬에 특수 반응**합니다:

- 약한 공격력 (8 데미지) - 느리게 접근하는 약한 적
- 번개(1번 스킬) 적중 시 **3초간 스턴** + 감전 애니메이션
- 스턴 중 이동/공격 불가, "STUNNED!" 텍스트 표시

### 상태 머신

```
            ┌─────────┐
            │ WANDER  │ ← 기본 상태 (느린 걷기, 1.2 속도)
            └────┬────┘
                 │ 감지 (7m)
                 ▼
            ┌─────────┐
            │  CHASE  │ (달리기, 3.5 속도)
            └────┬────┘
                 │ 사정거리 (1.8m)
                 ▼
            ┌─────────┐
            │ ATTACK  │ (left_jab, 8 데미지)
            └────┬────┘
                 │ 번개 스킬 적중
                 ▼
            ┌─────────┐
            │ STUNNED │ (3초, 감전 애니메이션 루프)
            └─────────┘
```

### 감전 (Electrocution) 구현

```gdscript
# 추가 상태 변수
var _is_stunned: bool = false
var _stun_timer: float = 0.0
const STUN_DURATION := 3.0

func apply_electrocution() -> void:
    if not is_alive:
        return
    _is_stunned = true
    _stun_timer = STUN_DURATION
    _is_attacking_anim = false        # 공격 중이었으면 취소
    velocity = Vector3.ZERO
    _sfx_electrocution.play()
    if _anim_player and _anim_electrocution != "":
        _anim_player.stop()
        _anim_player.play(_anim_electrocution)
    _spawn_stun_text()
```

**스턴 상태 처리** (`_physics_process` 상단):

```gdscript
if _is_stunned:
    _stun_timer -= delta
    velocity = Vector3.ZERO           # 이동 불가
    if _stun_timer <= 0.0:
        _is_stunned = false           # 스턴 해제
        _is_attacking_anim = false
        _current_anim = ""            # 다음 상태로 자연스럽게 전환
    return                             # 나머지 AI 로직 건너뜀
```

### 애니메이션 감지 (4가지)

```gdscript
func _detect_animations() -> void:
    for a in anims:
        var lower := a.to_lower()
        if "electrocution" in lower or "shock" in lower:
            _anim_electrocution = a   # ★ 감전 반응 (추가)
        elif "walk" in lower:
            _anim_walk = a
        elif "run" in lower:
            _anim_run = a
        elif "jab" in lower or "attack" in lower:
            _anim_attack = a
```

### 스턴 중 애니메이션 루프

감전 애니메이션이 끝나도 스턴 타이머가 남아있으면 다시 재생:

```gdscript
func _on_animation_finished(anim_name: String) -> void:
    if _is_stunned:
        if _anim_electrocution != "" and _stun_timer > 0.0:
            _anim_player.play(_anim_electrocution)  # 계속 반복
        return
    # ... 일반 공격 판정 ...
```

---

## 12. Enemy4 - 게으른 돌진 적

### 특징

평소에는 **걸어다니다 잠드는** 게으른 캐릭터지만, 플레이어가 가까이 오면 **돌진하여 강력한 한 방**을 날립니다:

- 높은 HP (180) + 높은 공격력 (65, 플레이어 HP의 약 1/3)
- 크리티컬 시 130 데미지 (HP의 절반 이상!)
- 배회 ↔ 수면 랜덤 반복 (게으른 패턴)
- 공격: running으로 플레이어에게 돌진 → 가까이 도달하면 roll_dodge 공격 + 지진 이펙트

### 상태 머신

```
     ┌──────────┐     3~5초 후     ┌──────────┐
     │  WANDER  │ ──────────────→ │  SLEEP   │
     │  (배회)   │ ←────────────── │  (수면)   │
     └────┬─────┘     8~15초 후    └────┬─────┘
          │ 감지 (3.5m)                  │ 감지 (3.5m)
          ▼                              ▼ (즉시 기상)
     ┌──────────┐
     │  CHARGE  │ ← running으로 돌진
     └────┬─────┘
          │ 사정거리 (1.2m)
          ▼
     ┌──────────┐
     │  ATTACK  │ ← roll_dodge + 지진 사운드 + 먼지 파티클
     └──────────┘
```

### 수면 사이클

```gdscript
func _fall_asleep() -> void:
    _is_sleeping = true
    _sleep_timer = randf_range(8.0, 15.0)  # 8~15초 수면
    velocity = Vector3.ZERO
    if _anim_sleep != "":
        _play_anim_force(_anim_sleep)      # 수면 애니메이션

func _do_sleep(delta: float) -> void:
    _sleep_timer -= delta
    # 1.5초마다 "z" 글자 떠오름
    _zzz_timer -= delta
    if _zzz_timer <= 0.0:
        _zzz_timer = 1.5
        _spawn_zzz()
    # 수면 애니메이션 루프
    if _anim_player and not _anim_player.is_playing():
        _anim_player.play(_anim_sleep)
    if _sleep_timer <= 0.0:
        _wake_up()
```

### "zzz" 떠오르는 이펙트

수면 중 1.5초마다 "z" 글자가 머리 위에서 떠오르며 사라집니다:

```gdscript
func _spawn_zzz() -> void:
    var label := Label3D.new()
    label.text = "z"
    label.font_size = 32
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    var node := Node3D.new()
    node.global_position = global_position + Vector3(0.3, 2.2, 0)
    node.add_child(label)
    get_tree().current_scene.add_child(node)
    var tween := node.create_tween()
    tween.tween_property(node, "position:y", node.position.y + 1.5, 2.0)
    tween.parallel().tween_property(label, "modulate:a", 0.0, 2.0).set_delay(0.5)
    tween.tween_callback(node.queue_free)
```

**왜 `add_child`가 아닌 `current_scene.add_child`?** 적이 이동하면 자식 노드도 같이 움직입니다. "z" 글자는 생성 위치에서 위로만 떠올라야 하므로 씬 루트에 추가합니다.

### 돌진 공격 (2단계)

**Phase 1: 달려가기**

```gdscript
func _do_charge(_delta: float) -> void:
    var to_target := _target.global_position - global_position
    to_target.y = 0.0
    var dist := to_target.length()

    if dist <= attack_range:    # 1.2m까지 접근
        # Phase 2로 전환: roll attack
        _attack_phase = 2
        _is_attacking_anim = true
        _sfx_attack.play()      # 지진 사운드
        _spawn_ground_shake()   # 먼지 파티클
        _anim_player.play(_anim_attack)  # roll_dodge 애니메이션
        return

    # 아직 멀면 계속 달려감
    velocity = to_target.normalized() * run_speed
    _play_anim(_anim_run)
```

**Phase 2: 공격 판정 (애니메이션 끝에서)**

```gdscript
func _on_animation_finished(anim_name: String) -> void:
    if _is_attacking_anim and _attack_phase == 2:
        _is_attacking_anim = false
        _attack_phase = 0
        if _target and dist <= attack_range + 0.5:
            _target.take_damage(attack_damage)  # 65 데미지!
        _awake_timer = randf_range(3.0, 5.0)    # 공격 후 다시 게으른 사이클
```

### 지진 먼지 이펙트

공격 시 발밑에 먼지 파티클이 폭발합니다:

```gdscript
func _spawn_ground_shake() -> void:
    var dust := GPUParticles3D.new()
    dust.one_shot = true
    dust.amount = 30
    dust.explosiveness = 0.9
    # 360도 방향으로 퍼짐
    pmat.spread = 180.0
    pmat.initial_velocity_min = 2.0
    pmat.initial_velocity_max = 4.0
    pmat.color = Color(0.6, 0.5, 0.3, 0.6)  # 흙빛 갈색
```

### 피격 시 기상

잠자는 중 데미지를 받으면 즉시 깨어납니다:

```gdscript
func take_damage(amount: float, is_crit: bool = false) -> void:
    # ...
    if _is_sleeping:
        _wake_up()    # ★ 잠에서 깨움
    if current_hp <= 0.0:
        _die()
```

### 스왑된 애니메이션 처리

GLB 모델의 애니메이션 이름이 실제 동작과 반대인 경우, 코드에서 매핑을 교체합니다:

```gdscript
func _detect_animations() -> void:
    for a in anims:
        var lower := a.to_lower()
        # NOTE: GLB에서 dodge=수면, sleep=공격으로 스왑됨
        if "roll" in lower or "dodge" in lower:
            _anim_sleep = a    # dodge 애니메이션 → 수면용
        elif "sleep" in lower:
            _anim_attack = a   # sleep 애니메이션 → 공격용
```

모델을 다시 리깅하지 않고도 코드에서 유연하게 해결할 수 있습니다.

---

## 13. 정리

| 적 | AI 특징 | 교훈 |
|---|---|---|
| Enemy | 단순 추격 + 원거리 | 기본 적 AI 패턴 |
| Enemy2 | 3상태 머신 (배회/추격/공격) | 상태 기반 AI 설계 |
| Enemy3 | 스턴 상태 추가 | `has_method()` 패턴으로 확장 |
| Enemy4 | 수면/기상 사이클 + 돌진 | 다단계 공격, 시각 이펙트(zzz, 먼지) |

---

## 다음 단계

이 시리즈의 이전 문서들:
- [04. 전투 시스템](04-combat-system.md) - 근접 공격, 크리티컬, 총기 사격, 감전 연동
- [07. 이펙트와 렌더링](07-effects-and-rendering.md) - 총알 이펙트, 머즐 플래시
- [08. 오디오](08-audio.md) - 사운드 시스템, 볼륨 조절
