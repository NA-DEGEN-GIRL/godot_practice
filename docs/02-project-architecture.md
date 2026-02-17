# 02. 프로젝트 아키텍처

이 문서는 프로젝트의 전체 구조, 파일 간 관계, 씬 트리 구성을 설명합니다.

---

## 1. 파일 구조와 역할

```
godot-test/
├── project.godot              # 프로젝트 설정 파일 (엔진 버전, 렌더러, 물리 등)
│
├── test_scene.tscn            # ★ 메인 씬 - 모든 것이 조합되는 곳
│
├── player.gd                  # 플레이어 로직 (이동, 공격, 스킬, HP)
├── player.tscn                # 플레이어 씬 (캡슐 메시 + 충돌체)
│
├── enemy.gd                   # 적 로직 (HP, 데미지, 사망, 리스폰)
├── enemy.tscn                 # 적 씬 (캡슐 메시 + 충돌체 + HP바)
│
├── camera_follow.gd           # 카메라 추적 (플레이어 따라가기)
├── skill_bar.gd               # UI: 스킬바 + HP/SP 게이지
│
├── lightning_effect.gd        # 번개 이펙트 (ImmediateMesh 지그재그)
├── lightning_effect.tscn       # 번개 씬 (Node3D + OmniLight3D)
│
├── flamethrower_effect.gd     # 화염방사기 이펙트 (GPUParticles3D + Area3D)
├── flamethrower_effect.tscn    # 화염방사기 씬 (Node3D)
│
├── sounds/                    # 효과음
│   ├── lightening_bolt_001.wav
│   └── fire_storm_001.wav
│
└── addons/godot_mcp/          # 에디터 애드온 (MCP 연동, 게임 로직과 무관)
```

### 파일 쌍(pair) 패턴

Godot에서는 `.gd`(스크립트)와 `.tscn`(씬)이 쌍을 이룹니다:

```
player.tscn  →  씬 구조 (어떤 노드들로 구성되는지)
player.gd    →  로직 (그 노드가 어떻게 동작하는지)
```

씬의 루트 노드에 스크립트를 연결하는 방식입니다. `.tscn` 파일 안에서:
```ini
[node name="Player" type="CharacterBody3D"]
script = ExtResource("1")  ← player.gd 연결
```

### 스크립트만 있는 경우

`camera_follow.gd`, `skill_bar.gd`는 별도 `.tscn` 없이 `test_scene.tscn`의 노드에 직접 연결됩니다:
```ini
[node name="Camera3D" type="Camera3D" parent="."]
script = ExtResource("camera_1")  ← camera_follow.gd 연결
```

---

## 2. 메인 씬 트리 (test_scene.tscn)

게임 실행 시 아래와 같은 씬 트리가 구성됩니다:

```
TestScene (Node3D)
│
├── WorldEnvironment                    # 환경 설정 (배경색, 앰비언트 라이트)
│
├── Camera3D (camera_follow.gd)         # 아이소메트릭 카메라
│   - Orthographic 투영 (원근 없음)
│   - 플레이어를 부드럽게 추적
│
├── DirectionalLight3D                  # 태양광 (그림자 활성화)
│
├── Ground (StaticBody3D)               # 바닥 (20x20 크기)
│   ├── MeshInstance3D                  # 녹색 박스 메시
│   └── CollisionShape3D               # 충돌 영역
│
├── Object (StaticBody3D)               # 정적 장애물 (빨간 박스)
│   ├── MeshInstance3D
│   └── CollisionShape3D
│
├── PushBox (RigidBody3D)               # 밀 수 있는 상자 (노란 박스)
│   ├── MeshInstance3D
│   └── CollisionShape3D
│
├── Player (CharacterBody3D) ← player.tscn 인스턴스
│   ├── MeshInstance3D                  # 파란 캡슐
│   ├── CollisionShape3D               # 충돌 영역
│   ├── HPBar (Node3D) ← 코드에서 생성  # 머리 위 HP 바
│   ├── AudioStreamPlayer ← 코드에서 생성 # 번개 효과음
│   └── AudioStreamPlayer ← 코드에서 생성 # 화염 효과음
│
├── Enemy (StaticBody3D) ← enemy.tscn 인스턴스
│   ├── MeshInstance3D                  # 진한 빨간 캡슐
│   ├── CollisionShape3D               # 충돌 영역
│   └── HPBar (Node3D)                 # 머리 위 HP 바
│       ├── Background (MeshInstance3D) # 회색 배경
│       ├── Fill (MeshInstance3D)       # 초록색 채움
│       └── Label3D ← 코드에서 생성     # HP 숫자
│
└── SkillBar (CanvasLayer) ← skill_bar.gd
    └── Control (FULL_RECT)             # 전체 화면 루트
        ├── HBoxContainer               # 스킬 슬롯 4개 (우측 하단)
        │   ├── Slot 0: ⚡ 번개
        │   ├── Slot 1: 🔥 화염
        │   ├── Slot 2: (비어있음)
        │   └── Slot 3: (비어있음)
        ├── HP Gauge (좌측 하단)
        └── SP Gauge (좌측 하단)
```

**"← 코드에서 생성"**: `.tscn` 파일에 없고, 스크립트의 `_ready()`에서 동적으로 만들어지는 노드들입니다.

---

## 3. 데이터 흐름

### 입력 → 행동

```
마우스 클릭
  → player.gd: _unhandled_input()
    → _handle_click(): 레이캐스트로 뭘 클릭했는지 판별
      → 적 클릭? → _attack_target 설정, 접근 후 공격
      → 빈 땅? → _move_to_ground()로 이동 목표 설정

키보드 1번
  → player.gd: _unhandled_input()
    → _use_skill(0)
      → 마우스 위치에 적이 있는지 레이캐스트
      → _cast_lightning(enemy): 데미지 + 이펙트 생성

키보드 2번 (누르고 있기)
  → player.gd: _start_flamethrower()
    → flamethrower_effect 인스턴스 생성
    → _physics_process에서 매 프레임 방향 업데이트
  → 키 떼기 → _stop_flamethrower()
```

### 데미지 흐름

```
플레이어 공격
  → player.gd: 크리티컬 판정 (20% 확률)
    → enemy.take_damage(damage, is_crit)
      → HP 감소
      → HP 바 업데이트 (바 크기 + 숫자 텍스트)
      → 데미지 숫자 생성 (떠오르며 사라짐)
      → HP ≤ 0? → _die()
        → 숨김 + 충돌 비활성화
        → 1~5초 타이머 → _respawn()
          → HP 복구 + 랜덤 위치에 다시 나타남
```

### 프레임 루프

```
매 프레임 (_process):
├── camera_follow.gd: 카메라 위치를 플레이어 쪽으로 보간
├── player.gd: HP 바를 카메라 방향으로 회전 (빌보드)
├── enemy.gd: HP 바를 카메라 방향으로 회전 (빌보드)
└── skill_bar.gd: 쿨타임 오버레이 + HP/SP 게이지 업데이트

매 물리 프레임 (_physics_process):
├── player.gd:
│   ├── 공격 타이머 감소
│   ├── 화염방사기 업데이트 (방향, 지속시간)
│   ├── 스킬 쿨타임 감소
│   ├── 공격 대상 추적 및 공격 실행
│   ├── 이동 (velocity → move_and_slide)
│   ├── 맵 경계 클램프
│   └── RigidBody 밀기
└── flamethrower_effect.gd: 데미지 틱 (0.5초마다)
```

---

## 4. 의존성 관계

```
test_scene.tscn
  ├── → player.tscn → player.gd
  │                      ├── → lightning_effect.tscn → lightning_effect.gd
  │                      ├── → flamethrower_effect.tscn → flamethrower_effect.gd
  │                      └── → sounds/*.wav
  ├── → enemy.tscn  → enemy.gd
  ├── → camera_follow.gd
  └── → skill_bar.gd
            └── → player (런타임 참조: ../Player)
```

**화살표(→) 의미:**
- `.tscn → .gd`: 씬이 스크립트를 참조
- `.gd → .tscn`: 스크립트가 `preload()`로 다른 씬 로드
- `skill_bar.gd → player`: 런타임에 `get_node("../Player")`로 참조

---

## 5. 설계 원칙

### 1. 씬 = 컴포넌트

각 게임 오브젝트는 독립적인 씬 파일입니다:
- `player.tscn`: 플레이어 캐릭터 (독립적으로 테스트 가능)
- `enemy.tscn`: 적 캐릭터
- `lightning_effect.tscn`: 일회성 이펙트 (스폰 → 애니메이션 → 자체 삭제)

### 2. 코드에서 노드 생성

이 프로젝트는 많은 노드를 `_ready()`에서 코드로 생성합니다:
- **장점**: `.tscn` 파일이 간결해지고, 동적 생성이 쉬움
- **단점**: 에디터에서 미리볼 수 없음
- **예**: HP 바, 스킬바 UI, 데미지 숫자, 파티클 등

### 3. 이펙트 = 일회용 씬

`lightning_effect`, `damage_number` 등은 스폰되고 애니메이션 후 `queue_free()`로 자체 삭제됩니다:
```gdscript
# 생성
var effect := scene.instantiate()
get_tree().current_scene.add_child(effect)

# (이펙트 내부에서) 애니메이션 끝나면 자체 삭제
tween.tween_callback(queue_free)
```

---

## 다음 단계

[03. 플레이어 이동](03-player-movement.md)에서 클릭 이동과 물리 시스템을 자세히 살펴봅니다.
