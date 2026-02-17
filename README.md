# Godot Isometric RPG Prototype

Godot 4.x 기반의 아이소메트릭 뷰 RPG 프로토타입입니다. 클릭 이동, 전투, 스킬 시스템, UI 등 RPG의 핵심 메카닉을 구현하고 있습니다.

## 주요 기능

- **아이소메트릭 카메라**: Orthographic 투영, 부드러운 캐릭터 추적
- **클릭 투 무브**: 좌클릭으로 이동, 드래그로 연속 이동 (디아블로 스타일)
- **전투 시스템**: 적 클릭 공격, 크리티컬 히트 (20% 확률, 2배 데미지)
- **스킬 시스템**:
  - ⚡ **번개 (1번키)**: 대상 지정 즉발 스킬, 지그재그 번개 이펙트, 1초 쿨타임
  - 🔥 **화염방사기 (2번키)**: 홀드형 지속 스킬, GPU 파티클, 최대 5초 사용 후 5초 쿨타임
  - 💨 **순간이동 (3번키)**: 마우스 방향으로 순간이동, 장애물 충돌 체크, 카메라 흔들림, 10초 쿨타임
- **HP/데미지 시스템**: 3D HP 바, 떠오르는 데미지 숫자 (일반/크리티컬 구분)
- **UI**: 스킬바 (쿨타임 애니메이션), HP/SP 게이지
- **물리**: 정적 장애물 충돌, RigidBody3D 밀기
- **사운드**: 스킬별 효과음

## 실행 방법

1. [Godot 4.x](https://godotengine.org/download) 설치 (4.3 이상 권장)
2. 이 레포지토리를 클론:
   ```bash
   git clone https://github.com/NA-DEGEN-GIRL/godot_practice.git
   ```
3. Godot에서 `project.godot` 파일 열기
4. `test_scene.tscn`을 메인 씬으로 설정 후 F5 또는 F6으로 실행

> **참고**: 에디터 내장 게임 뷰포트에서 실행할 때는 상단의 "입력" 토글을 활성화해야 마우스/키보드 입력이 게임에 전달됩니다.

## 조작법

| 입력 | 동작 |
|------|------|
| 좌클릭 (빈 땅) | 해당 위치로 이동 |
| 좌클릭 드래그 | 마우스 따라 연속 이동 |
| 좌클릭 (적) | 적에게 접근 후 근접 공격 |
| 1번 키 | ⚡ 번개 스킬 (마우스가 적 위에 있어야 함) |
| 2번 키 (홀드) | 🔥 화염방사기 (마우스 방향으로 발사) |
| 3번 키 | 💨 순간이동 (마우스 방향으로 텔레포트) |

## 프로젝트 구조

```
godot-test/
├── test_scene.tscn          # 메인 테스트 씬 (모든 것이 조합되는 곳)
├── player.gd / player.tscn  # 플레이어 (이동, 공격, 스킬, HP)
├── enemy.gd / enemy.tscn    # 적 (HP, 데미지, 사망, 리스폰)
├── camera_follow.gd         # 부드러운 카메라 추적
├── skill_bar.gd             # 스킬바 UI + HP/SP 게이지
├── lightning_effect.gd/tscn # 번개 스킬 이펙트
├── flamethrower_effect.gd/tscn # 화염방사기 이펙트
├── teleport_effect.gd/tscn    # 순간이동 이펙트
├── sounds/                  # 효과음
│   ├── lightening_bolt_001.wav
│   ├── fire_storm_001.wav
│   └── fast_teleportation_001.wav
├── addons/godot_mcp/        # Godot MCP 에디터 애드온
├── models/                  # AI 생성 3D 모델 (.glb 등)
├── .mcp.json                # MCP 서버 설정 파일
└── docs/                    # 학습 문서 (아래 참고)
```

## 학습 문서

이 프로젝트를 통해 Godot을 공부하기 위한 상세 문서입니다:

1. **[Godot 기초 개념](docs/01-godot-basics.md)** - 씬, 노드, GDScript, 시그널 등 핵심 개념
2. **[프로젝트 아키텍처](docs/02-project-architecture.md)** - 전체 구조와 씬 트리 구성
3. **[플레이어 이동](docs/03-player-movement.md)** - 클릭 이동, 레이캐스팅, 물리
4. **[전투 시스템](docs/04-combat-system.md)** - 공격, 데미지, 크리티컬, HP
5. **[스킬 시스템](docs/05-skill-system.md)** - 번개, 화염방사기, 쿨타임
6. **[UI와 HUD](docs/06-ui-and-hud.md)** - 스킬바, 게이지, 데미지 숫자
7. **[이펙트와 렌더링](docs/07-effects-and-rendering.md)** - 파티클, ImmediateMesh, 머티리얼
8. **[오디오](docs/08-audio.md)** - 사운드 재생과 루프
9. **[MCP와 AI 에셋 파이프라인](docs/09-mcp-ai-pipeline.md)** - MCP 서버 구성과 AI 기반 에셋 생성

## MCP 서버 및 AI 에셋 파이프라인

이 프로젝트는 **MCP (Model Context Protocol)** 를 통해 AI가 게임 개발의 다양한 단계를 직접 지원합니다. `.mcp.json`에 4개의 MCP 서버가 설정되어 있습니다.

### 사용 중인 MCP 서버

| MCP 서버 | 패키지 | 역할 |
|----------|--------|------|
| **godot-mcp** | `@satelliteoflove/godot-mcp` | Godot 에디터 제어 (씬/노드 편집, 프로젝트 실행, 스크린샷 등) |
| **game-asset-gen** | `mcp-game-asset-gen` | 2D 이미지/텍스처/캐릭터 시트/픽셀아트 생성 (Gemini AI) |
| **meshy-ai** | `meshy-ai-mcp-server` | 2D 이미지를 3D 모델로 변환, 텍스처링, 리메시 |
| **ElevenLabs** | `elevenlabs-mcp` | TTS 음성/사운드 생성 |

### AI 에셋 파이프라인 흐름

```
[텍스트 프롬프트]
      │
      ▼
 game-asset-gen ──→ 2D 이미지 (캐릭터, 텍스처, 픽셀아트)
      │
      ▼
  meshy-ai ──→ 3D 모델 (.glb) + 텍스처링 + 리메시
      │
      ▼
  godot-mcp ──→ Godot 씬에 배치, 스크립트 연결, 테스트 실행
      │
 ElevenLabs ──→ 음성/효과음 생성 (.mp3)
```

자세한 내용은 **[MCP와 AI 에셋 파이프라인](docs/09-mcp-ai-pipeline.md)** 문서를 참고하세요.

## 기술 스택

- **엔진**: Godot 4.x (Forward+ 렌더러)
- **물리**: Jolt Physics
- **언어**: GDScript
- **에디터 연동**: Godot MCP (Model Context Protocol)
- **AI 에셋 생성**: game-asset-gen (Gemini), meshy-ai (3D 변환), ElevenLabs (음성)
