# 08. 오디오

이 문서는 Godot의 오디오 시스템과 이 프로젝트에서의 사운드 구현을 설명합니다.

---

## 1. AudioStreamPlayer

Godot의 오디오 재생 노드입니다.

### 종류

```
AudioStreamPlayer    → 2D 사운드 (위치 무관, 항상 같은 볼륨)
AudioStreamPlayer2D  → 2D 게임용 위치 기반 사운드
AudioStreamPlayer3D  → 3D 게임용 위치 기반 사운드 (거리에 따라 볼륨 변화)
```

이 프로젝트에서는 `AudioStreamPlayer`(비위치)를 사용합니다. 플레이어의 스킬 사운드는 항상 일정한 볼륨으로 들려야 하기 때문입니다.

### 기본 사용법

```gdscript
# 생성
var sfx := AudioStreamPlayer.new()
sfx.stream = preload("res://sounds/lightening_bolt_001.wav")
add_child(sfx)  # 씬 트리에 추가해야 재생 가능

# 재생
sfx.play()

# 정지
sfx.stop()

# 재생 중인지 확인
if sfx.playing:
    pass
```

### 이 프로젝트에서의 사용 (player.gd)

```gdscript
var _sfx_lightning: AudioStreamPlayer
var _sfx_fire: AudioStreamPlayer

func _ready() -> void:
    # 번개 효과음
    _sfx_lightning = AudioStreamPlayer.new()
    _sfx_lightning.stream = preload("res://sounds/lightening_bolt_001.wav")
    add_child(_sfx_lightning)

    # 화염 효과음
    _sfx_fire = AudioStreamPlayer.new()
    _sfx_fire.stream = preload("res://sounds/fire_storm_001.wav")
    _sfx_fire.finished.connect(_on_fire_sfx_finished)  # 루프용
    add_child(_sfx_fire)
```

---

## 2. preload vs load

```gdscript
# preload: 스크립트 파싱 시점에 로드 (게임 시작 시)
var stream := preload("res://sounds/bolt.wav")
# 장점: 처음에 다 로드하므로 재생 시 지연 없음
# 단점: 메모리를 미리 차지

# load: 코드 실행 시점에 로드 (필요할 때)
var stream := load("res://sounds/bolt.wav")
# 장점: 필요할 때만 메모리 사용
# 단점: 첫 재생 시 약간의 지연 가능

# 이 프로젝트에서는 모든 사운드를 preload 사용
# 사운드 파일이 작고, 즉시 재생되어야 하므로
```

---

## 3. 사운드 루프 구현

### 문제: WAV 파일 루프

WAV 파일에 루프 설정을 할 수 있지만, Godot의 WAV 임포터 설정(압축 모드 등)에 따라 런타임에서 `loop_mode` 변경이 작동하지 않을 수 있습니다.

### 해결: finished 시그널 방식

```gdscript
# 시그널 연결
_sfx_fire.finished.connect(_on_fire_sfx_finished)

# 사운드가 끝날 때 호출되는 콜백
func _on_fire_sfx_finished() -> void:
    if _flamethrower_active:
        _sfx_fire.play()  # 아직 사용 중이면 다시 재생
```

**동작 흐름:**
```
1. 화염방사기 시작 → _sfx_fire.play()
2. 사운드 재생 완료 → finished 시그널 발생
3. _on_fire_sfx_finished() 호출
4. _flamethrower_active가 true? → _sfx_fire.play() (다시 재생)
5. 반복...
6. 화염방사기 중지 → _sfx_fire.stop()
   다음 finished 시그널에서 _flamethrower_active가 false → 재생 안 함
```

**이 방식의 장점:**
- WAV 압축 포맷과 무관하게 작동
- 루프 여부를 코드로 제어 가능
- 디버깅이 쉬움

### 대안: 임포트 설정에서 루프

Godot 에디터에서 `.wav` 파일을 선택하고 Import 탭에서:
```
edit/loop_mode = 1 (Forward)
edit/loop_begin = 0
edit/loop_end = -1 (끝까지)
```

이후 `Reimport`를 클릭하면 파일 자체가 루프됩니다. 하지만 압축 모드(`compress/mode`)에 따라 작동하지 않을 수 있어서 이 프로젝트에서는 시그널 방식을 사용합니다.

---

## 4. 오디오 버스 (Audio Bus)

Godot은 **오디오 버스** 시스템을 제공합니다 (이 프로젝트에서는 기본 설정 사용):

```
Master Bus (기본)
├── SFX Bus (효과음)      → 볼륨 조절, 이펙트 적용 가능
├── Music Bus (배경음악)   → 별도 볼륨 조절
└── UI Bus (UI 사운드)     → 별도 볼륨 조절
```

버스를 설정하려면:
```gdscript
sfx.bus = "SFX"  # "SFX" 버스로 출력
```

프로젝트 규모가 커지면 버스를 분리해서 "효과음만 끄기", "배경음악만 끄기" 같은 옵션을 구현할 수 있습니다.

---

## 5. 전투/아이템 사운드

### 총소리 (gunshot.wav)

Python + scipy로 합성한 짧은 노이즈 버스트:

```gdscript
# player.gd _ready()에서
_sfx_gunshot = AudioStreamPlayer.new()
_sfx_gunshot.stream = preload("res://sounds/gunshot.wav")
add_child(_sfx_gunshot)

# 발사 시
_sfx_gunshot.play()
```

### 치킨 먹는 소리 (gulp.wav)

아이템 획득 시 일회용 AudioStreamPlayer를 생성하는 패턴:

```gdscript
# chicken_pickup.gd
func _on_body_entered(body: Node3D) -> void:
    body.heal_hp(HEAL_AMOUNT)
    # ★ 치킨이 삭제되므로 사운드를 씬 루트에 추가
    var sfx := AudioStreamPlayer.new()
    sfx.stream = preload("res://sounds/gulp.wav")
    sfx.bus = "Master"
    get_tree().current_scene.add_child(sfx)
    sfx.play()
    sfx.finished.connect(sfx.queue_free)   # 재생 끝나면 자동 삭제
    queue_free()   # 치킨 즉시 삭제
```

**왜 `add_child(sfx)`가 아닌 `current_scene.add_child(sfx)`인가?**

`queue_free()`로 치킨을 삭제하면 자식 노드도 함께 삭제됩니다. 사운드를 치킨의 자식으로 추가하면 소리가 중간에 끊깁니다. 씬 루트에 추가하면 치킨이 삭제돼도 사운드는 끝까지 재생됩니다.

### 좀비 그로울 (zombie_groan.wav)

Enemy2의 공격 사운드. `pitch_scale`로 변형합니다:

```gdscript
# enemy2.gd
_sfx_attack = AudioStreamPlayer.new()
_sfx_attack.stream = preload("res://sounds/zombie_groan.wav")
_sfx_attack.volume_db = -3.0
add_child(_sfx_attack)

# 공격 시
_sfx_attack.pitch_scale = randf_range(0.8, 1.2)   # ★ 매번 다른 음높이
_sfx_attack.play()
```

**`pitch_scale` 기법:**
- `0.8` = 느리고 낮은 소리 (크고 무거운 느낌)
- `1.0` = 원본
- `1.2` = 빠르고 높은 소리 (작고 날카로운 느낌)

하나의 WAV로도 0.8~1.2 랜덤 범위를 주면 매번 다르게 들려 반복감이 줄어듭니다. 풋스텝, 타격음, 총소리 등 반복적인 효과음에 널리 사용됩니다.

### 탄약 픽업 소리

같은 gulp.wav를 높은 pitch로 재사용:

```gdscript
# ammo_pickup.gd
sfx.stream = preload("res://sounds/gulp.wav")
sfx.pitch_scale = 1.8   # 원본보다 훨씬 높고 빠르게 → 금속 딸깍 느낌
```

**사운드 재사용 팁**: pitch_scale을 크게 바꾸면 같은 파일이라도 완전히 다른 소리처럼 들립니다. 별도 파일 없이 다양한 효과를 만들 수 있습니다.

---

## 6. 사운드 파일 목록

| 파일 | 용도 | 생성 방법 |
|------|------|-----------|
| `lightening_bolt_001.wav` | 번개 스킬 | 외부 에셋 |
| `fire_storm_001.wav` | 화염방사기 | 외부 에셋 |
| `fast_teleportation_001.wav` | 텔레포트 | 외부 에셋 |
| `gunshot.wav` | 권총 발사 | Python scipy 합성 |
| `gulp.wav` | 치킨/탄약 픽업 | Python scipy 합성 |
| `poison_spit.wav` | 적 독 공격 | Python scipy 합성 |
| `zombie_groan.wav` | 적2 근접 공격 | Python scipy 합성 |

---

## 7. 정리

| 개념 | 설명 |
|------|------|
| `AudioStreamPlayer` | 위치 무관 사운드 (UI, 스킬음) |
| `AudioStreamPlayer3D` | 3D 위치 기반 사운드 (발소리, 환경음) |
| `preload()` | 미리 로드 (즉시 재생 필요 시) |
| `.play()` / `.stop()` | 재생 / 정지 |
| `finished` 시그널 | 재생 완료 시 호출 |
| 오디오 버스 | 사운드 카테고리별 볼륨/이펙트 제어 |
