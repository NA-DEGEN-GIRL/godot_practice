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

## 5. 정리

| 개념 | 설명 |
|------|------|
| `AudioStreamPlayer` | 위치 무관 사운드 (UI, 스킬음) |
| `AudioStreamPlayer3D` | 3D 위치 기반 사운드 (발소리, 환경음) |
| `preload()` | 미리 로드 (즉시 재생 필요 시) |
| `.play()` / `.stop()` | 재생 / 정지 |
| `finished` 시그널 | 재생 완료 시 호출 |
| 오디오 버스 | 사운드 카테고리별 볼륨/이펙트 제어 |
