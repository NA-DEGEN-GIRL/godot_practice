# 09. MCP와 AI 에셋 파이프라인

이 문서는 프로젝트에서 사용하는 MCP (Model Context Protocol) 서버들과, AI를 활용한 게임 에셋 생성 파이프라인을 설명합니다.

---

## 1. MCP란 무엇인가?

**MCP (Model Context Protocol)** 는 AI 모델이 외부 도구와 상호작용할 수 있게 해주는 표준 프로토콜입니다. Claude 같은 AI가 단순히 텍스트를 생성하는 것을 넘어서, 실제로 파일을 생성하고 에디터를 조작하고 3D 모델을 만드는 등의 작업을 수행할 수 있게 합니다.

### 기본 구조

```
사용자 (자연어 요청)
      │
      ▼
Claude AI ──── MCP 프로토콜 ────→ MCP 서버 ──→ 외부 도구/API
                                     │
                                     ▼
                              결과 반환 (파일, 데이터 등)
```

### 설정 파일: `.mcp.json`

프로젝트 루트의 `.mcp.json` 파일에서 사용할 MCP 서버들을 정의합니다:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "@satelliteoflove/godot-mcp"]
    },
    "meshy-ai": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "meshy-ai-mcp-server"],
      "env": {
        "MESHY_API_KEY": "your-api-key"
      }
    },
    "game-asset-gen": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "mcp-game-asset-gen"],
      "env": {
        "GEMINI_API_KEY": "your-api-key",
        "ALLOWED_TOOLS": "gemini_generate_image,generate_character_sheet,generate_pixel_art_character,generate_texture"
      }
    },
    "ElevenLabs": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "elevenlabs-mcp"],
      "env": {
        "ELEVENLABS_API_KEY": "your-api-key"
      }
    }
  }
}
```

각 서버는 `npx`를 통해 Node.js 패키지로 실행됩니다. `env`에 필요한 API 키를 설정합니다.

---

## 2. godot-mcp: Godot 에디터 제어

**패키지**: `@satelliteoflove/godot-mcp`

AI가 Godot 에디터를 직접 제어할 수 있게 해주는 MCP 서버입니다. 코드를 작성하는 것 뿐 아니라, 씬을 구성하고, 노드를 배치하고, 게임을 실행/테스트하는 모든 작업을 AI가 수행할 수 있습니다.

### 통신 구조

```
Claude AI ←→ Node.js MCP 서버 ←→ WebSocket (포트 6550) ←→ Godot EditorPlugin
                                                              │
                                                       EngineDebugger
                                                              │
                                                       실행 중인 게임
```

### 주요 기능

| 기능 | 설명 | 예시 |
|------|------|------|
| **씬 관리** | 씬 열기, 생성, 저장 | `scene.open("res://test_scene.tscn")` |
| **노드 편집** | 노드 생성, 수정, 삭제, 재배치 | 캐릭터 노드 생성 후 위치 설정 |
| **스크립트 관리** | 스크립트 연결, 분리 | 노드에 GDScript 파일 연결 |
| **프로젝트 실행** | 게임 실행/중지 | F5 실행과 동일한 효과 |
| **스크린샷** | 에디터/게임 화면 캡처 | AI가 현재 상태를 시각적으로 확인 |
| **디버그 출력** | 게임 로그, 에러 확인 | 런타임 오류 디버깅 |
| **입력 주입** | 실행 중인 게임에 키 입력 | 자동 테스트 |
| **애니메이션** | AnimationPlayer 조회/편집 | 애니메이션 생성 및 키프레임 편집 |
| **타일맵** | TileMapLayer 데이터 조회/편집 | 맵 타일 배치 |
| **3D 공간 정보** | 노드의 위치, 바운딩 박스 조회 | 3D 씬 레이아웃 확인 |

### 사용 예시: AI에게 씬 구성 요청

```
사용자: "적 캐릭터를 플레이어 앞에 3개 배치해줘"

AI가 수행하는 작업:
1. 현재 씬 트리 조회 (node.find)
2. 플레이어 위치 확인 (scene3d.get_spatial_info)
3. 적 씬 인스턴스 3개 생성 (node.create)
4. 각 적의 위치 설정 (node.update)
5. 씬 저장 (scene.save)
```

### Godot 에디터 설정

Godot 에디터에서 `addons/godot_mcp/` 플러그인이 활성화되어 있어야 합니다:
1. 프로젝트 > 프로젝트 설정 > 플러그인
2. "Godot MCP" 플러그인을 "활성"으로 설정
3. 에디터 하단에 "MCP" 상태 패널이 표시됨

---

## 3. game-asset-gen: 2D 이미지 생성

**패키지**: `mcp-game-asset-gen`

Google의 **Gemini AI**를 사용하여 게임용 2D 에셋을 생성합니다. 텍스트 프롬프트만으로 캐릭터, 텍스처, 픽셀아트 등을 만들 수 있습니다.

### 지원하는 도구들

#### 3-1. `gemini_generate_image` - 범용 이미지 생성

텍스트 프롬프트로 어떤 이미지든 생성합니다.

```
입력: "판타지 RPG 마법사 캐릭터, 아이소메트릭 뷰, plain white background"
출력: PNG 이미지 파일
```

- `plain white background` 또는 `plain black background` 지정 시 투명 배경 변환 가능
- 기존 이미지를 입력으로 넣어 변형(variation)도 가능

#### 3-2. `generate_character_sheet` - 캐릭터 시트

여러 포즈와 표정이 포함된 캐릭터 레퍼런스 시트를 생성합니다.

```
입력:
  - characterDescription: "갑옷을 입은 기사, 빨간 망토"
  - style: "anime"
  - includePoses: true
  - includeExpressions: true
출력: 다양한 포즈/표정이 담긴 캐릭터 시트 PNG
```

#### 3-3. `generate_pixel_art_character` - 픽셀아트

레트로 스타일 게임용 픽셀아트 캐릭터를 생성합니다.

```
입력:
  - characterDescription: "파란 슬라임 몬스터"
  - pixelDimensions: "32x32"
  - transparentBackground: true
  - spriteSheet: true
출력: 투명 배경 픽셀아트 (스프라이트 시트 포함 가능)
```

지원 해상도: `8x8`, `16x16`, `32x32`, `48x48`, `64x64`, `96x96`

#### 3-4. `generate_texture` - 텍스처 생성

3D 환경용 텍스처를 생성합니다.

```
입력:
  - textureDescription: "이끼 낀 돌담"
  - seamless: true (타일링 가능)
  - textureSize: "1024x1024"
  - materialType: "diffuse"
출력: 심리스 텍스처 PNG
```

텍스처 타입: `diffuse`, `normal`, `roughness`, `displacement`

### API 키 설정

[Google AI Studio](https://aistudio.google.com/)에서 Gemini API 키를 발급받아 `.mcp.json`의 `GEMINI_API_KEY`에 설정합니다.

---

## 4. meshy-ai: 2D에서 3D로 변환

**패키지**: `meshy-ai-mcp-server`

**Meshy AI**를 사용하여 2D 이미지를 3D 모델로 변환하거나, 텍스트만으로 3D 모델을 생성합니다. game-asset-gen으로 만든 2D 이미지를 3D 게임 에셋으로 변환하는 핵심 단계입니다.

### 주요 기능

#### 4-1. Text-to-3D: 텍스트에서 3D 모델 생성

```
입력: "중세 판타지 보물 상자, 나무와 금속 장식"
출력: 텍스처가 입혀진 3D 모델 (.glb, .fbx 등)
```

작업 흐름:
1. `create_text_to_3d_task` - 생성 작업 시작
2. `stream_text_to_3d_task` - 진행 상황 실시간 확인 (수 분 소요)
3. 완료 후 `.glb` 파일 다운로드 URL 제공

#### 4-2. Image-to-3D: 이미지에서 3D 모델 생성

```
입력: game-asset-gen으로 만든 캐릭터 이미지 URL
출력: 해당 캐릭터의 3D 모델
```

이것이 AI 에셋 파이프라인의 핵심입니다:
1. game-asset-gen으로 캐릭터 콘셉트 이미지 생성
2. meshy-ai의 Image-to-3D로 3D 모델 변환
3. 필요시 리메시(remesh)로 폴리곤 최적화

#### 4-3. Text-to-Texture: 3D 모델에 텍스처 입히기

이미 있는 3D 모델에 새로운 텍스처를 생성해 입힙니다.

```
입력:
  - model_url: 3D 모델 파일 URL
  - object_prompt: "이끼 낀 고대 석상"
  - style_prompt: "판타지 RPG 스타일"
  - enable_pbr: true (물리 기반 렌더링 텍스처)
출력: 텍스처가 입혀진 3D 모델
```

#### 4-4. Remesh: 3D 모델 최적화

생성된 3D 모델의 폴리곤 수를 줄이고 토폴로지를 정리합니다.

```
입력:
  - input_task_id: 이전 3D 생성 작업 ID
  - target_polycount: 5000
  - topology: "quad" 또는 "triangle"
출력: 최적화된 3D 모델 (.glb, .fbx 등)
```

게임 성능을 위해 중요한 단계입니다. AI가 생성한 모델은 보통 폴리곤 수가 많으므로, 리메시를 통해 게임에 적합한 수준으로 줄입니다.

#### 4-5. Rigging & Animation: 리깅과 애니메이션

3D 모델에 뼈대(rig)를 추가하고 애니메이션을 적용합니다.

```
리깅: 3D 모델에 스켈레톤(뼈대) 자동 생성
애니메이션: 걷기, 달리기 등 동작 적용
```

### API 키 설정

[Meshy AI](https://www.meshy.ai/)에서 API 키를 발급받아 `.mcp.json`의 `MESHY_API_KEY`에 설정합니다.

---

## 5. ElevenLabs: 음성 및 사운드 생성

**패키지**: `elevenlabs-mcp`

**ElevenLabs**의 TTS (Text-to-Speech) 기술을 사용하여 게임용 음성과 대사를 생성합니다.

### 주요 기능

#### 5-1. `tts_generate_speech` - 텍스트를 음성으로 변환

```
입력:
  - text: "용사여, 이 마을을 구해주시오!"
  - voice_id: "21m00Tcm4TlvDq8ikWAM" (Rachel 음성)
  - stability: 0.5
  - similarity_boost: 0.75
출력: MP3 파일
```

#### 5-2. `tts_list_voices` - 사용 가능한 음성 목록

다양한 음성을 미리 확인하고 선택할 수 있습니다. 남성/여성, 다양한 억양, 감정 톤 등을 고를 수 있습니다.

#### 5-3. `tts_get_voice_settings` - 음성 설정 조회

특정 음성의 기본 설정값(안정성, 유사도 등)을 확인합니다.

### 활용 사례

| 용도 | 예시 |
|------|------|
| NPC 대사 | 퀘스트 안내, 상점 대화 등 |
| 내레이션 | 스토리 진행 나레이션 |
| 보이스오버 | 컷씬, 튜토리얼 안내 |
| 효과음 보조 | 캐릭터 감탄사, 전투 구호 |

### API 키 설정

[ElevenLabs](https://elevenlabs.io/)에서 API 키를 발급받아 `.mcp.json`의 `ELEVENLABS_API_KEY`에 설정합니다.

---

## 6. AI 에셋 파이프라인: 전체 흐름

텍스트 프롬프트 하나로 게임 에셋을 생성하고 Godot 프로젝트에 배치하는 전체 과정입니다.

### 예시: "고블린 적 캐릭터 만들기"

```
단계 1: 콘셉트 이미지 생성 (game-asset-gen)
────────────────────────────────────────────
"녹색 고블린, 나무 방패와 단검, 아이소메트릭 뷰, plain white background"
  → goblin_concept.png (투명 배경 2D 이미지)

단계 2: 3D 모델 변환 (meshy-ai)
────────────────────────────────
goblin_concept.png → Image-to-3D 변환
  → 고블린 3D 모델 (텍스처 포함)
  → Remesh로 폴리곤 최적화 (게임용)
  → .glb 파일 다운로드

단계 3: 음성 생성 (ElevenLabs)
──────────────────────────────
"끼에에엑!" → goblin_scream.mp3
"크르르..." → goblin_idle.mp3

단계 4: Godot 프로젝트에 배치 (godot-mcp)
──────────────────────────────────────────
1. .glb 파일을 프로젝트에 임포트
2. 적 씬(enemy.tscn) 구조 생성:
   - CharacterBody3D (루트)
     - MeshInstance3D (고블린 3D 모델)
     - CollisionShape3D (충돌 영역)
     - AudioStreamPlayer3D (음성)
3. 스크립트 연결
4. 테스트 실행으로 동작 확인
```

### 파이프라인 다이어그램

```
 ┌─────────────────────────────────────────────────────────┐
 │                    사용자 (자연어 요청)                     │
 │          "녹색 고블린 적 캐릭터를 만들어줘"                   │
 └────────────────────────┬────────────────────────────────┘
                          │
                          ▼
 ┌─────────────────────────────────────────────────────────┐
 │                      Claude AI                          │
 │              (작업 계획 수립 및 도구 호출)                   │
 └───┬──────────┬──────────┬──────────┬────────────────────┘
     │          │          │          │
     ▼          ▼          ▼          ▼
 ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
 │game-   │ │meshy-  │ │Eleven  │ │godot-    │
 │asset-  │ │ai      │ │Labs    │ │mcp       │
 │gen     │ │        │ │        │ │          │
 ├────────┤ ├────────┤ ├────────┤ ├──────────┤
 │2D 이미지│ │3D 모델 │ │음성    │ │에디터    │
 │생성    │ │변환    │ │생성    │ │제어      │
 └───┬────┘ └───┬────┘ └───┬────┘ └────┬─────┘
     │          │          │           │
     ▼          ▼          ▼           ▼
   .png       .glb       .mp3     씬 구성/배치
     │          │          │           │
     └──────────┴──────────┴───────────┘
                          │
                          ▼
              ┌──────────────────────┐
              │   완성된 게임 에셋     │
              │   (Godot 프로젝트)    │
              └──────────────────────┘
```

---

## 7. 실습: 직접 해보기

### 7-1. 사전 준비

1. **API 키 발급**
   - [Google AI Studio](https://aistudio.google.com/) - Gemini API 키
   - [Meshy AI](https://www.meshy.ai/) - Meshy API 키
   - [ElevenLabs](https://elevenlabs.io/) - ElevenLabs API 키

2. **`.mcp.json` 설정**
   - 프로젝트 루트의 `.mcp.json` 파일에 API 키를 입력
   - 보안을 위해 이 파일은 `.gitignore`에 추가 권장

3. **Godot MCP 애드온 활성화**
   - Godot 에디터에서 프로젝트 > 프로젝트 설정 > 플러그인
   - "Godot MCP" 활성화

### 7-2. 간단한 텍스처 생성 예시

Claude에게 다음과 같이 요청할 수 있습니다:

```
"돌바닥 텍스처를 만들어서 프로젝트에 저장해줘"
```

AI가 자동으로:
1. `generate_texture`로 심리스 돌바닥 텍스처 생성
2. 프로젝트 폴더에 PNG 파일로 저장
3. 필요시 Godot 에디터에서 머티리얼에 적용

### 7-3. 캐릭터 생성 예시

```
"판타지 스타일의 여전사 캐릭터를 만들어서 씬에 배치해줘"
```

AI가 자동으로:
1. 캐릭터 콘셉트 이미지 생성
2. 3D 모델로 변환
3. Godot 씬에 노드 생성 및 배치

---

## 8. 비용 및 제한 사항

| 서비스 | 무료 티어 | 참고 |
|--------|-----------|------|
| **Gemini AI** (game-asset-gen) | 무료 할당량 있음 | 이미지당 수 초 소요 |
| **Meshy AI** | 월 200 크레딧 무료 | 3D 변환 1건당 수 분 소요 |
| **ElevenLabs** | 월 10,000자 무료 | 음성 합성 수 초 소요 |
| **Godot MCP** | 완전 무료 (오픈소스) | 로컬 실행 |

### 주의사항

- API 키는 `.mcp.json`에 직접 입력합니다. 이 파일이 Git에 커밋되지 않도록 `.gitignore`에 추가하세요.
- 3D 모델 생성은 몇 분이 소요될 수 있습니다. `stream_*` 도구로 진행 상황을 확인하세요.
- 생성된 에셋의 품질은 프롬프트에 크게 의존합니다. 구체적이고 명확한 설명을 사용하세요.

---

## 9. 정리

| 도구 | 입력 | 출력 | 용도 |
|------|------|------|------|
| `game-asset-gen` | 텍스트 프롬프트 | 2D 이미지 (PNG) | 콘셉트 아트, 텍스처, 픽셀아트 |
| `meshy-ai` | 이미지 또는 텍스트 | 3D 모델 (GLB/FBX) | 게임 오브젝트, 캐릭터 |
| `ElevenLabs` | 텍스트 | 음성 파일 (MP3) | NPC 대사, 나레이션 |
| `godot-mcp` | 명령어 | 에디터 조작 | 씬 구성, 테스트, 디버깅 |

이 4가지 MCP 서버를 조합하면, **텍스트 설명만으로 2D 이미지 생성 -> 3D 모델 변환 -> 음성 생성 -> Godot 씬 배치**까지 전체 에셋 파이프라인을 AI가 자동으로 수행할 수 있습니다. 개발자는 자연어로 원하는 것을 설명하기만 하면 됩니다.
